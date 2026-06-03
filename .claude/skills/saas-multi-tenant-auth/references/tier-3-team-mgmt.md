# Tier 3 — Team Management RPCs

**What ships**: `change_member_role`, `set_member_status`, `remove_member`, `transfer_ownership` RPCs + last-owner guard trigger.
**Template**: `templates/03_team_mgmt.sql`
**Verification gate**: owner-transfer atomic test passes; demote-last-owner blocked.

## Why RPCs, not direct UPDATEs

RLS would technically allow owner/admin to UPDATE `{{membership_table}}` directly, but:
1. **Owner transfer requires promote-BEFORE-demote** (Pillar 6) — single transaction, atomic ordering
2. **Server-side enum validation** — clients can't be trusted with role strings
3. **Single audit hook-point** — all team mutations route through these RPCs, easier to audit-log
4. **Specific error codes** for each business-rule violation → Pillar 12 actionable UI

## The four RPCs

### 1. `change_member_role(p_membership_id, p_new_role)`
- Caller must be owner/admin of target's org
- Promotion to `owner` requires caller is also `owner` (use `transfer_ownership` instead)
- Last-owner demote blocked by trigger

### 2. `set_member_status(p_membership_id, p_new_status)`
- Same auth check
- Suspending last active owner blocked by trigger
- Used for "deactivate without deleting"

### 3. `remove_member(p_membership_id)`
- Same auth check
- **Self-removal blocked** — must ask another admin or transfer ownership first
- Last active owner removal blocked by trigger

### 4. `transfer_ownership(p_to_membership_id)` — the masterpiece
```sql
-- Caller must be current owner
-- Step 1: Promote target → org has 2 active owners (transient)
-- Step 2: Demote caller → org has 1 active owner (trigger satisfied)
-- Both in single transaction
RETURNS TABLE (new_owner ..., old_owner ...)
```

## The last-owner guard trigger

```sql
CREATE OR REPLACE FUNCTION public.{{prefix}}_block_last_owner_demote()
RETURNS trigger LANGUAGE plpgsql
AS $$
DECLARE v_active_owner_count int;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    -- Demote attempt: was owner+active, now NOT (owner+active)
    IF OLD.role = 'owner' AND OLD.status = 'active'
       AND (NEW.role <> 'owner' OR NEW.status <> 'active') THEN
      SELECT count(*) INTO v_active_owner_count
      FROM {{membership_table}}
      WHERE org_id = OLD.org_id AND role = 'owner' AND status = 'active'
        AND id <> OLD.id;
      IF v_active_owner_count = 0 THEN
        RAISE EXCEPTION 'Cannot demote/suspend last active owner. Transfer ownership first.'
          USING ERRCODE = '42501';
      END IF;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.role = 'owner' AND OLD.status = 'active' THEN
      SELECT count(*) INTO v_active_owner_count
      FROM {{membership_table}}
      WHERE org_id = OLD.org_id AND role = 'owner' AND status = 'active'
        AND id <> OLD.id;
      IF v_active_owner_count = 0 THEN
        RAISE EXCEPTION 'Cannot remove last active owner. Transfer ownership first.'
          USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END $$;

CREATE TRIGGER trg_{{prefix}}_block_last_owner_demote
  BEFORE UPDATE OR DELETE ON {{membership_table}}
  FOR EACH ROW EXECUTE FUNCTION {{prefix}}_block_last_owner_demote();
```

This trigger is the safety net for `transfer_ownership` and the explicit guard for `change_member_role` / `remove_member`.

## Verification gate (must pass before Tier 4)

### Test 1: Demote last owner blocked
```sql
-- Setup: Org with single owner Alice
-- Action: SELECT change_member_role(<alice_membership_id>, 'admin');
-- Expected: ERROR with ERRCODE 42501, message about last owner
```

### Test 2: Owner-transfer atomic ordering
```sql
-- Setup: Alice (owner), Bob (admin) in same org
-- Action: SELECT * FROM transfer_ownership(<bob_membership_id>);
-- Expected: 
--   - Bob.role = 'owner'
--   - Alice.role = 'admin'
--   - Org has exactly 1 active owner (Bob)
--   - No exception raised
```

### Test 3: Self-removal blocked
```sql
-- Setup: Alice is admin in org (not owner)
-- Action: SELECT remove_member(<alice_membership_id>); (called as Alice)
-- Expected: ERROR with message "You cannot remove yourself..."
```

### Test 4: Invalid role rejected
```sql
-- Action: SELECT change_member_role(<id>, 'super_admin');
-- Expected: ERROR with ERRCODE 22023, "Invalid role"
```

## What NOT to do in Tier 3

- ❌ Allow direct UPDATE on `{{membership_table}}` from authenticated role (RLS should require RPC route)
- ❌ Skip the last-owner guard ("we'll add it later")
- ❌ Implement transfer_ownership as two separate RPC calls (not atomic — race window)
- ❌ Promote to owner via change_member_role (use transfer_ownership for the explicit hand-off)
