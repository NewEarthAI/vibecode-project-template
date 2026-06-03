/**
 * Error classifier — Pillar 12 (every 4xx renders specific actionable UI state)
 *
 * Critical: FunctionsHttpError.context is a RAW Response object,
 * NOT a pre-parsed body. Read it once via `await ctx.json()`.
 */

import { FunctionsHttpError } from '@supabase/supabase-js';

export interface ErrorPayload {
  code: string;
  message: string;
  details?: Record<string, unknown>;
}

/**
 * Extract { code, message, details } from any thrown error.
 * Handles FunctionsHttpError specifically; falls back gracefully.
 */
export async function extractErrorPayload(err: unknown): Promise<ErrorPayload> {
  if (err instanceof FunctionsHttpError) {
    const ctx = err.context as Response;
    try {
      const body = await ctx.json();
      return {
        code: body.code ?? 'unknown_error',
        message: body.error ?? 'Unknown error',
        details: body.details,
      };
    } catch {
      return { code: 'parse_error', message: 'Failed to parse error response' };
    }
  }
  if (err instanceof Error) {
    return { code: 'generic_error', message: err.message };
  }
  return { code: 'unknown_error', message: String(err) };
}

/**
 * Standard code → UI action mapping.
 * Customize the navigate/toast helpers per your project.
 */
export interface ErrorHandlerOptions {
  navigate: (path: string) => void;
  toastError: (message: string, opts?: { action?: { label: string; onClick: () => void } }) => void;
  retryFn?: () => void;
}

export async function handleError(err: unknown, opts: ErrorHandlerOptions): Promise<void> {
  const { code, message, details } = await extractErrorPayload(err);
  const { navigate, toastError, retryFn } = opts;

  switch (code) {
    case 'unauthenticated':
      navigate('/auth');
      break;

    case 'forbidden':
      toastError(`You don't have permission. ${message}`);
      break;

    case 'user_exists_use_login': {
      const email = (details?.email as string) ?? '';
      const params = email ? `?email=${encodeURIComponent(email)}&mode=signin` : '?mode=signin';
      navigate(`/auth${params}`);
      break;
    }

    case 'already_member':
      toastError('You are already a member of this organization.');
      break;

    case 'invite_expired':
      toastError('This invite has expired. Ask for a new one.');
      break;

    case 'email_send_failed':
      toastError(message, retryFn ? {
        action: { label: 'Retry', onClick: retryFn }
      } : undefined);
      break;

    case 'validation_error':
      toastError(message);
      break;

    case 'db_error':
    case 'auth_error':
    case 'internal_error':
    default:
      toastError(message || 'Something went wrong. Try again or contact support.');
      break;
  }
}
