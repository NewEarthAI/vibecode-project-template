// accept-invite v1.0 — parameterized edge function
//
// Contract:
//   POST { token, password?, display_name? }
//   200  { success: true, org_id, org_name, user_id, status: 'claimed'|'already_claimed' }
//   4xx  { error, code, details? }
//
// CRITICAL: NEVER 500 on race conditions — duplicate inserts return 200 already_claimed.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const MIN_PASSWORD_LENGTH = 8;

function jsonResponse(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function errorResponse(error: string, code: string, status: number, details?: Record<string, unknown>) {
  return jsonResponse({ error, code, ...(details ? { details } : {}) }, status);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  if (req.method !== 'POST') return errorResponse('Method not allowed', 'method_not_allowed', 405);

  const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    const body = await req.json() as { token?: string; password?: string; display_name?: string };
    const { token, password, display_name } = body;

    if (!token || typeof token !== 'string') {
      return errorResponse('Missing or invalid token', 'validation_error', 400);
    }

    // === Lookup invite ===
    const { data: invite } = await supabaseAdmin
      .from('{{invite_table}}')
      .select('id, org_id, invited_email, role, invited_by, expires_at, claimed_at, claimed_by')
      .eq('token', token)
      .maybeSingle();

    if (!invite) return errorResponse('Invalid invite', 'invalid_token', 404);

    const { data: org } = await supabaseAdmin
      .from('{{org_table}}')
      .select('id, name, slug')
      .eq('id', invite.org_id)
      .maybeSingle();
    if (!org) return errorResponse('Organization not found', 'not_found', 404);

    // === Pillar 5: Idempotent already-claimed → 200, NOT 4xx ===
    if (invite.claimed_at) {
      return jsonResponse({
        success: true,
        org_id: org.id,
        org_name: org.name,
        org_slug: org.slug,
        user_id: invite.claimed_by,
        status: 'already_claimed',
      }, 200);
    }

    if (new Date(invite.expires_at).getTime() < Date.now()) {
      return errorResponse('Invite expired', 'invite_expired', 410);
    }

    const normalizedEmail = invite.invited_email.trim().toLowerCase();

    // === Find or create auth.users (Pillar 10 — pagination-safe RPC) ===
    const { data: existingUserIdRaw, error: lookupErr } = await supabaseAdmin.rpc(
      'get_auth_user_id_by_email', { p_email: normalizedEmail },
    );
    if (lookupErr) return errorResponse('Lookup failed', 'auth_error', 500);
    const existingUserId = existingUserIdRaw as string | null;

    let userId: string;
    if (existingUserId) {
      // Pillar 12: code = user_exists_use_login → UI flips to sign-in form
      if (password) {
        return errorResponse(
          'An account exists. Sign in to accept the invite.',
          'user_exists_use_login',
          400,
        );
      }
      userId = existingUserId;
    } else {
      if (!password || password.length < MIN_PASSWORD_LENGTH) {
        return errorResponse(
          `Password required (min ${MIN_PASSWORD_LENGTH} chars)`,
          'validation_error',
          400,
        );
      }
      if (!display_name?.trim()) {
        return errorResponse('display_name required', 'validation_error', 400);
      }

      const { data: createRes, error: createErr } = await supabaseAdmin.auth.admin.createUser({
        email: normalizedEmail,
        password,
        email_confirm: true,
        user_metadata: { display_name: display_name.trim() },
      });

      if (createErr || !createRes?.user) {
        const msg = createErr?.message ?? '';
        // Race: pre-check missed concurrent signup
        if (/already.*regist|already.*exist|duplicate|user_exist/i.test(msg)) {
          return errorResponse(
            'An account exists. Sign in to accept the invite.',
            'user_exists_use_login',
            400,
          );
        }
        return errorResponse(msg || 'Auth error', 'auth_error', 500);
      }
      userId = createRes.user.id;
    }

    // === Pillar 5: Atomic claim via RPC ===
    let claimedOk = false;
    let claimAlreadyDone = false;

    const { data: rpcRes, error: rpcErr } = await supabaseAdmin.rpc(
      'accept_invite_atomic', { p_token: token, p_user_id: userId },
    );

    if (!rpcErr) {
      if (rpcRes && (Array.isArray(rpcRes) ? rpcRes.length > 0 : true)) {
        claimedOk = true;
      } else {
        claimAlreadyDone = true;
      }
    }

    // === Fallback: manual sequential claim if RPC unavailable ===
    if (!claimedOk && !claimAlreadyDone) {
      const { data: claimedRow } = await supabaseAdmin
        .from('{{invite_table}}')
        .update({ claimed_at: new Date().toISOString(), claimed_by: userId })
        .eq('token', token)
        .is('claimed_at', null)
        .gt('expires_at', new Date().toISOString())
        .select('id, org_id, role, invited_by')
        .maybeSingle();

      if (!claimedRow) {
        // Race winner already done — return idempotent success
        const { data: refetched } = await supabaseAdmin
          .from('{{invite_table}}')
          .select('claimed_by').eq('token', token).maybeSingle();
        return jsonResponse({
          success: true, org_id: org.id, org_name: org.name, org_slug: org.slug,
          user_id: refetched?.claimed_by ?? userId,
          status: 'already_claimed',
        }, 200);
      }

      const { error: membershipErr } = await supabaseAdmin
        .from('{{membership_table}}')
        .upsert({
          org_id: claimedRow.org_id,
          user_id: userId,
          role: claimedRow.role,
          status: 'active',
          invited_by: claimedRow.invited_by,
        }, { onConflict: 'org_id,user_id', ignoreDuplicates: true });

      if (membershipErr) {
        const isUniqueViolation = membershipErr.code === '23505'
          || /duplicate key/i.test(membershipErr.message ?? '');
        if (!isUniqueViolation) {
          return errorResponse('Failed to create membership', 'db_error', 500);
        }
        // Race: treat as success per Pillar 5
      }
      claimedOk = true;
    }

    return jsonResponse({
      success: true,
      org_id: org.id,
      org_name: org.name,
      org_slug: org.slug,
      user_id: userId,
      status: 'claimed',
    }, 200);
  } catch (e) {
    return errorResponse(
      'Internal server error',
      'internal_error',
      500,
      { message: e instanceof Error ? e.message : String(e) },
    );
  }
});
