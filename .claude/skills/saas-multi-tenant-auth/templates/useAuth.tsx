/**
 * useAuth — parameterized template with bare-auth inner pattern
 *
 * Two providers:
 *   1. AuthProvider (outer) — owns user/session
 *   2. AuthInner — calls useOrganization, exposes activeOrg/membership
 *
 * The bare-auth context exposes only user.id to useOrganization, breaking
 * the chicken-and-egg of useOrganization needing the same context it lives in.
 */

import { createContext, useContext, useEffect, useRef, useState, ReactNode } from 'react';
import type { User, Session } from '@supabase/supabase-js';
import * as Sentry from '@sentry/react';
import { supabase } from '@/integrations/supabase/client';
import {
  useOrganization,
  type Organization,
  type OrgMembership,
} from '@/hooks/useOrganization';

interface AuthContextType {
  user: User | null;
  session: Session | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<{ error: Error | null }>;
  signUp: (email: string, password: string) => Promise<{ error: Error | null; userId: string | null }>;
  signInWithMagicLink: (email: string) => Promise<{ error: Error | null }>;
  signOut: () => Promise<void>;
  resetPassword: (email: string) => Promise<{ error: Error | null }>;
  // Org context
  activeOrg: Organization | null;
  activeMembership: OrgMembership | null;
  memberships: OrgMembership[];
  switchOrg: (orgId: string) => void;
  orgsLoading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);
const BareAuthContext = createContext<{ user: User | null } | undefined>(undefined);

export function useBareAuthUser(): User | null {
  const ctx = useContext(BareAuthContext);
  return ctx?.user ?? null;
}

function AuthInner({
  user, session, loading, signIn, signUp, signInWithMagicLink, signOut, resetPassword, children,
}: Omit<AuthContextType, 'activeOrg' | 'activeMembership' | 'memberships' | 'switchOrg' | 'orgsLoading'>
  & { children: ReactNode }) {
  const orgContext = useOrganization();

  // Sentry org tagging — every event tagged with org_slug, org_id, org_role
  const lastSyncedOrgId = useRef<string | null | undefined>(undefined);
  useEffect(() => {
    const orgId = orgContext.activeOrg?.id ?? null;
    if (lastSyncedOrgId.current === orgId) return;
    lastSyncedOrgId.current = orgId;
    if (orgContext.activeOrg) {
      Sentry.setTag('org_slug', orgContext.activeOrg.slug ?? 'unknown');
      Sentry.setTag('org_id', orgContext.activeOrg.id);
      Sentry.setTag('org_role', orgContext.activeMembership?.role ?? 'none');
    } else {
      Sentry.setTag('org_slug', 'none');
      Sentry.setTag('org_id', 'none');
      Sentry.setTag('org_role', 'none');
    }
  }, [orgContext.activeOrg, orgContext.activeMembership]);

  return (
    <AuthContext.Provider value={{
      user, session, loading,
      signIn, signUp, signInWithMagicLink, signOut, resetPassword,
      activeOrg: orgContext.activeOrg,
      activeMembership: orgContext.activeMembership,
      memberships: orgContext.memberships,
      switchOrg: orgContext.switchOrg,
      orgsLoading: orgContext.isLoading,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, session) => {
        setSession(session);
        setUser(session?.user ?? null);
        setLoading(false);
        if (session?.user) {
          Sentry.setUser({ id: session.user.id, email: session.user.email ?? undefined });
        } else if (event === 'SIGNED_OUT') {
          Sentry.setUser(null);
        }
      }
    );

    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setUser(session?.user ?? null);
      setLoading(false);
    });

    return () => subscription.unsubscribe();
  }, []);

  const signIn = async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    return { error: error as Error | null };
  };

  const signUp = async (email: string, password: string) => {
    const redirectUrl = `${window.location.origin}/auth/callback`;
    const { data, error } = await supabase.auth.signUp({
      email, password, options: { emailRedirectTo: redirectUrl },
    });
    return { error: error as Error | null, userId: data.user?.id ?? null };
  };

  const signInWithMagicLink = async (email: string) => {
    const redirectUrl = `${window.location.origin}/auth/callback`;
    const { error } = await supabase.auth.signInWithOtp({
      email, options: { emailRedirectTo: redirectUrl },
    });
    return { error: error as Error | null };
  };

  const signOut = async () => {
    await supabase.auth.signOut();
  };

  const resetPassword = async (email: string) => {
    const redirectUrl = `${window.location.origin}/auth?mode=reset`;
    const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo: redirectUrl });
    return { error: error as Error | null };
  };

  return (
    <BareAuthContext.Provider value={{ user }}>
      <AuthInner
        user={user} session={session} loading={loading}
        signIn={signIn} signUp={signUp} signInWithMagicLink={signInWithMagicLink}
        signOut={signOut} resetPassword={resetPassword}
      >
        {children}
      </AuthInner>
    </BareAuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) throw new Error('useAuth must be used within an AuthProvider');
  return context;
}
