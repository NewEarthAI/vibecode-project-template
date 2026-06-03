# Tier 4 — Append-Only Audit Log

**What ships**: `{{audit_table}}` with belt-and-suspenders append-only enforcement, capture triggers on `{{membership_table}}` and `{{invite_table}}`.
**Template**: `templates/04_audit_log.sql`
**Verification gate**: pen-test T13 (UPDATE/DELETE on audit_table raises) passes; capture triggers fire on every team mutation.

## What audit must capture

| Event | Source | Actor |
|---|---|---|
| `member_invited` | INSERT on `{{invite_table}}` | `auth.uid()` or `NEW.invited_by` |
| `member_joined` | INSERT on `{{membership_table}}` | `auth.uid()` or `NEW.user_id` (the joiner IS the actor for self-initiated joins via accept_invite_atomic) |
| `member_role_changed` | UPDATE on `{{membership_table}}` where `role` distinct | `auth.uid()` |
| `member_status_changed` | UPDATE on `{{membership_table}}` where `status` distinct | `auth.uid()` |
| `member_removed` | DELETE on `{{membership_table}}` | `auth.uid()` |
| `invite_cancelled` | DELETE on `{{invite_table}}` where claimed_at IS NULL | `auth.uid()` only (no fallback to invited_by — would misattribute) |

## The append-only contract (Pillar 7 deep dive)

THREE layers, not two:

### Layer 1: RLS policies
```sql
ALTER TABLE {{audit_table}} ENABLE ROW LEVEL SECURITY;
CREATE POLICY audit_no_update ON {{audit_table}} FOR UPDATE USING (false);
CREATE POLICY audit_no_delete ON {{audit_table}} FOR DELETE USING (false);
```

### Layer 2: Structural BEFORE triggers
```sql
CREATE OR REPLACE FUNCTION fn_{{audit_table}}_no_mutate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION '{{audit_table}} is append-only (operation % forbidden)', TG_OP
    USING ERRCODE = '42501';
END $$;

CREATE TRIGGER trg_{{audit_table}}_no_update
  BEFORE UPDATE ON {{audit_table}}
  FOR EACH ROW EXECUTE FUNCTION fn_{{audit_table}}_no_mutate();
CREATE TRIGGER trg_{{audit_table}}_no_delete
  BEFORE DELETE ON {{audit_table}}
  FOR EACH ROW EXECUTE FUNCTION fn_{{audit_table}}_no_mutate();
```

### Layer 3: Permission revoke
```sql
REVOKE INSERT, UPDATE, DELETE ON {{audit_table}} FROM authenticated, anon, public;
GRANT SELECT ON {{audit_table}} TO authenticated;
```

The capture triggers run as `SECURITY DEFINER` so they bypass these revokes for INSERT. But a future migration that accidentally adds `GRANT INSERT ON {{audit_table}} TO authenticated` is now structurally unable to enable forged audit rows because the SELECT/INSERT capture triggers are the only path that satisfies RLS — direct `INSERT INTO {{audit_table}}` from a user JWT would still fail RLS predicates.

## Capture trigger pattern

```sql
CREATE OR REPLACE FUNCTION fn_audit_{{membership_table}}()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_actor uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- For self-initiated joins via service-role RPC, fall back to NEW.user_id
    v_actor := COALESCE(auth.uid(), NEW.user_id);
    INSERT INTO {{audit_table}} (
      org_id, actor_user_id, event_type, target_membership_id, target_user_id, after_value
    ) VALUES (
      NEW.org_id, v_actor, 'member_joined', NEW.id, NEW.user_id,
      jsonb_build_object('role', NEW.role, 'status', NEW.status)
    );
  ELSIF TG_OP = 'UPDATE' THEN
    v_actor := auth.uid();
    -- One row per changed dimension
    IF OLD.role IS DISTINCT FROM NEW.role THEN
      INSERT INTO {{audit_table}} (
        org_id, actor_user_id, event_type, target_membership_id, target_user_id, before_value, after_value
      ) VALUES (
        NEW.org_id, v_actor, 'member_role_changed', NEW.id, NEW.user_id,
        jsonb_build_object('role', OLD.role),
        jsonb_build_object('role', NEW.role)
      );
    END IF;
    -- ... same for status ...
  ELSIF TG_OP = 'DELETE' THEN
    -- Skip cascade-deletes from org deletion (avoid noise)
    IF NOT EXISTS (SELECT 1 FROM {{org_table}} WHERE id = OLD.org_id) THEN
      RETURN OLD;
    END IF;
    v_actor := auth.uid();
    INSERT INTO {{audit_table}} (...) VALUES (...);
  END IF;
  RETURN COALESCE(NEW, OLD);

EXCEPTION WHEN OTHERS THEN
  -- ZERO-REGRESSION GUARANTEE: audit failure must NOT block business ops
  RAISE WARNING '[audit] % on % failed: %', TG_OP, TG_TABLE_NAME, SQLERRM;
  RETURN COALESCE(NEW, OLD);
END $$;
```

**The EXCEPTION handler is critical** — if audit insert fails (e.g., disk full, constraint violation), the parent business operation MUST still succeed. Audit is observability, not business logic. Never let it block the team-management mutation.

## NULL-actor handling

`accept_invite_atomic` runs under service-role JWT. Inside the RPC, `auth.uid()` returns NULL. For `member_joined` INSERTs, fall back to `NEW.user_id` — the joiner IS the actor for self-initiated joins. Semantically correct.

For `invite_cancelled` DELETEs, do NOT fall back to `OLD.invited_by` — that would misattribute cancellations to the original inviter. NULL actor for service-initiated cancels is semantically correct.

## RLS on audit reads

```sql
CREATE POLICY audit_log_read ON {{audit_table}} FOR SELECT TO authenticated
USING (
  is_admin(auth.uid())
  OR ((auth.jwt() ->> 'role'::text) = 'service_role'::text)
  OR {{prefix}}_is_org_owner_or_admin(auth.uid(), org_id)
);
```

Members cannot read audit log. Compliance-grade visibility scoping.

## Verification gate (must pass before Tier 5)

### Test 1: Audit row appears on every mutation
```sql
SELECT change_member_role('<id>', 'admin');
SELECT * FROM {{audit_table}}
WHERE event_type = 'member_role_changed'
  AND target_membership_id = '<id>'
ORDER BY created_at DESC LIMIT 1;
-- Expected: 1 row with before_value/after_value populated
```

### Test 2: UPDATE on audit_table raises
```sql
-- Connect as service_role (bypasses RLS but NOT structural triggers)
UPDATE {{audit_table}} SET event_type = 'tampered' WHERE id = '<some-id>';
-- Expected: ERROR 42501 "is append-only (operation UPDATE forbidden)"
```

### Test 3: DELETE on audit_table raises
```sql
DELETE FROM {{audit_table}} WHERE id = '<some-id>';
-- Expected: ERROR 42501 "is append-only (operation DELETE forbidden)"
```

### Test 4: Audit failure doesn't block parent mutation
```sql
-- Force audit insert to fail (e.g., temporarily ALTER COLUMN to make NOT NULL)
-- Then perform a member role change
-- Expected: role change SUCCEEDS, audit row missing, RAISE WARNING in logs
```

All four must pass.
