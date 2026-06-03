// send-invite v1.0 — parameterized edge function
// Replace {{placeholders}} before deploying.
//
// Contract:
//   POST { org_id, invited_email, role: 'admin'|'manager'|'member' }
//   200  { success: true, invite_id, token, expires_at }
//   4xx  { error, code, details? }
//   5xx  { error, code: 'email_send_failed', details }
//
// CRITICAL: invited_by is derived from JWT (caller.id), NEVER from request body.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!;
const FRONTEND_URL = Deno.env.get('FRONTEND_URL') ?? '{{frontend_url}}';
const FROM_EMAIL = Deno.env.get('INVITE_FROM_EMAIL') ?? '{{from_email}}';

const ALLOWED_ROLES = new Set(['admin', 'manager', 'member']);
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const INVITE_TTL_DAYS = 7;

function jsonResponse(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function errorResponse(error: string, code: string, status: number, details?: Record<string, unknown>) {
  return jsonResponse({ error, code, ...(details ? { details } : {}) }, status);
}

function generateInviteToken(): string {
  const uuidPart = crypto.randomUUID().replace(/-/g, '');
  const rand = new Uint8Array(16);
  crypto.getRandomValues(rand);
  const randHex = Array.from(rand, (b) => b.toString(16).padStart(2, '0')).join('');
  return `${uuidPart}${randHex}`;  // 64 chars
}

function escapeHtml(s: string): string {
  return String(s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function buildInviteEmailHtml(opts: {
  orgName: string; inviterName: string; role: string; acceptUrl: string;
}): string {
  const { orgName, inviterName, role, acceptUrl } = opts;
  const esc = escapeHtml;
  return `<!DOCTYPE html>
<html><body style="font-family:sans-serif;padding:32px;background:#F8FAFC;">
  <div style="max-width:560px;margin:0 auto;background:white;border-radius:12px;padding:32px;">
    <h2 style="color:#0F172A;">You're invited to join ${esc(orgName)}</h2>
    <p style="color:#475569;line-height:1.6;">
      <strong>${esc(inviterName)}</strong> invited you to join <strong>${esc(orgName)}</strong>
      as <strong>${esc(role)}</strong>.
    </p>
    <p style="margin:32px 0;text-align:center;">
      <a href="${acceptUrl}" style="background:#3B82F6;color:white;padding:12px 32px;
                                       border-radius:8px;text-decoration:none;font-weight:600;">
        Accept invitation
      </a>
    </p>
    <p style="color:#94A3B8;font-size:12px;text-align:center;">
      This invite expires in ${INVITE_TTL_DAYS} days.<br>
      If the button doesn't work, paste this link: <br>
      <a href="${acceptUrl}" style="color:#3B82F6;word-break:break-all;">${acceptUrl}</a>
    </p>
  </div>
</body></html>`;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  if (req.method !== 'POST') return errorResponse('Method not allowed', 'method_not_allowed', 405);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return errorResponse('Missing authorization', 'unauthenticated', 401);

  const supabaseUser = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    const body = await req.json() as { org_id?: string; invited_email?: string; role?: string };
    const { org_id, invited_email, role } = body;

    // === Validation ===
    if (!org_id || !invited_email || !role) {
      return errorResponse('Missing required fields', 'validation_error', 400);
    }
    if (!EMAIL_REGEX.test(invited_email)) {
      return errorResponse('Invalid email', 'validation_error', 400);
    }
    if (!ALLOWED_ROLES.has(role)) {
      return errorResponse(`Invalid role`, 'validation_error', 400);
    }
    const normalizedEmail = invited_email.trim().toLowerCase();

    // === Auth (Pillar 4 — JWT-derived identity) ===
    const { data: { user: caller } } = await supabaseUser.auth.getUser();
    if (!caller) return errorResponse('Authentication failed', 'unauthenticated', 401);

    // === Authorization (caller is owner/admin of target org) ===
    const { data: callerMembership } = await supabaseAdmin
      .from('{{membership_table}}')
      .select('role, status')
      .eq('user_id', caller.id)
      .eq('org_id', org_id)
      .maybeSingle();

    if (!callerMembership || callerMembership.status !== 'active'
        || !['owner', 'admin'].includes(callerMembership.role)) {
      return errorResponse('Only owners/admins can invite', 'forbidden', 403);
    }

    // === Verify org exists ===
    const { data: org } = await supabaseAdmin
      .from('{{org_table}}')
      .select('id, name')
      .eq('id', org_id)
      .maybeSingle();
    if (!org) return errorResponse('Organization not found', 'not_found', 404);

    // === Already-member check (Pillar 10 — pagination-safe RPC) ===
    const { data: existingUserId } = await supabaseAdmin.rpc(
      'get_auth_user_id_by_email', { p_email: normalizedEmail },
    );
    if (existingUserId) {
      const { data: existingMembership } = await supabaseAdmin
        .from('{{membership_table}}')
        .select('id, status')
        .eq('user_id', existingUserId)
        .eq('org_id', org_id)
        .maybeSingle();
      if (existingMembership?.status === 'active') {
        return errorResponse('Already a member', 'already_member', 400);
      }
    }

    // === Idempotent insert/update on {{invite_table}} ===
    const token = generateInviteToken();
    const expiresAt = new Date(Date.now() + INVITE_TTL_DAYS * 24 * 60 * 60 * 1000).toISOString();
    const inviterUserId = caller.id;  // ← Pillar 4: JWT-derived, NEVER from body

    const { data: existingInvite } = await supabaseAdmin
      .from('{{invite_table}}')
      .select('id')
      .eq('org_id', org_id)
      .eq('invited_email', normalizedEmail)
      .is('claimed_at', null)
      .maybeSingle();

    let inviteId: string;
    if (existingInvite) {
      const { data: updated, error } = await supabaseAdmin
        .from('{{invite_table}}')
        .update({
          role, invited_by: inviterUserId, token, expires_at: expiresAt,
          send_status: 'pending', send_error_message: null, sent_at: null,
        })
        .eq('id', existingInvite.id)
        .select('id').single();
      if (error || !updated) return errorResponse('Failed to refresh invite', 'db_error', 500);
      inviteId = updated.id;
    } else {
      const { data: inserted, error } = await supabaseAdmin
        .from('{{invite_table}}')
        .insert({
          org_id, invited_email: normalizedEmail, role, invited_by: inviterUserId,
          token, expires_at: expiresAt, send_status: 'pending',
        })
        .select('id').single();
      if (error || !inserted) return errorResponse('Failed to create invite', 'db_error', 500);
      inviteId = inserted.id;
    }

    // === Send via Resend ===
    const inviterName = (caller.user_metadata?.display_name as string)
      ?? (caller.user_metadata?.full_name as string)
      ?? caller.email ?? 'A teammate';
    const acceptUrl = `${FRONTEND_URL}/invite/accept?token=${encodeURIComponent(token)}&email=${encodeURIComponent(normalizedEmail)}`;
    const subject = `You're invited to join ${org.name}`;
    const html = buildInviteEmailHtml({ orgName: org.name, inviterName, role, acceptUrl });

    let resendOk = false;
    let resendError = '';
    let resendMessageId: string | null = null;
    try {
      const resendRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ from: FROM_EMAIL, to: normalizedEmail, subject, html }),
      });
      if (resendRes.ok) {
        resendOk = true;
        const body = await resendRes.json() as { id?: string };
        resendMessageId = body.id ?? null;
      } else {
        resendError = await resendRes.text();
      }
    } catch (e) {
      resendError = e instanceof Error ? e.message : String(e);
    }

    // === Pillar 12: surface failure with actionable code ===
    if (resendOk) {
      await supabaseAdmin
        .from('{{invite_table}}')
        .update({
          send_status: 'sent', sent_at: new Date().toISOString(),
          resend_message_id: resendMessageId,
        })
        .eq('id', inviteId);
      return jsonResponse({ success: true, invite_id: inviteId, token, expires_at: expiresAt }, 200);
    }

    await supabaseAdmin
      .from('{{invite_table}}')
      .update({
        send_status: 'failed',
        send_error_message: resendError.slice(0, 1000),
      })
      .eq('id', inviteId);

    return errorResponse(
      'Failed to send invitation email',
      'email_send_failed',  // ← Pillar 12: UI shows Retry button
      500,
      { invite_id: inviteId, resend_error: resendError.slice(0, 500) },
    );
  } catch (e) {
    return errorResponse(
      'Internal server error',
      'internal_error',
      500,
      { message: e instanceof Error ? e.message : String(e) },
    );
  }
});
