/**
 * useOrganization Hook — parameterized template
 *
 * Replace {{placeholders}}:
 *   {{membership_table}} — e.g., bb_org_memberships
 *   {{org_table}}        — e.g., bb_organizations
 *
 * Wires Pillar 11: realtime subscription on memberships + JWT refresh + complete query invalidation on org switch.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useBareAuthUser } from '@/hooks/useAuth';

const ACTIVE_ORG_STORAGE_KEY = 'app_active_org_id';
export const ORG_SWITCHED_EVENT = 'app:org-switched';

export interface Organization {
  id: string;
  name: string;
  slug: string | null;
  created_at: string;
}

export type OrgRole = 'owner' | 'admin' | 'manager' | 'member';
export type OrgMemberStatus = 'active' | 'suspended' | 'pending';

export interface OrgMembership {
  id: string;
  org_id: string;
  user_id: string;
  role: OrgRole;
  status: OrgMemberStatus;
  joined_at: string | null;
  // Supabase joined relation
  '{{org_table}}': Organization | null;
}

interface UseOrganizationReturn {
  activeOrg: Organization | null;
  activeMembership: OrgMembership | null;
  memberships: OrgMembership[];
  switchOrg: (orgId: string) => void;
  isLoading: boolean;
  error: Error | null;
}

function readStoredOrgId(): string | null {
  if (typeof window === 'undefined') return null;
  try { return window.localStorage.getItem(ACTIVE_ORG_STORAGE_KEY); }
  catch { return null; }
}

function writeStoredOrgId(orgId: string | null) {
  if (typeof window === 'undefined') return;
  try {
    if (orgId) window.localStorage.setItem(ACTIVE_ORG_STORAGE_KEY, orgId);
    else window.localStorage.removeItem(ACTIVE_ORG_STORAGE_KEY);
  } catch { /* swallow quota */ }
}

export function useOrganization(): UseOrganizationReturn {
  const user = useBareAuthUser();
  const queryClient = useQueryClient();
  const [activeOrgId, setActiveOrgId] = useState<string | null>(() => readStoredOrgId());
  const channelRef = useRef<ReturnType<typeof supabase.channel> | null>(null);

  const membershipsQuery = useQuery({
    queryKey: ['org-memberships', user?.id],
    enabled: !!user?.id,
    staleTime: 30 * 1000,
    queryFn: async (): Promise<OrgMembership[]> => {
      if (!user?.id) return [];
      const { data, error } = await supabase
        .from('{{membership_table}}')
        .select('id, org_id, user_id, role, status, joined_at, {{org_table}}(id, name, slug, created_at)')
        .eq('user_id', user.id)
        .eq('status', 'active');
      if (error) throw error;
      return (data ?? []) as unknown as OrgMembership[];
    },
  });

  const memberships = useMemo<OrgMembership[]>(
    () => membershipsQuery.data ?? [],
    [membershipsQuery.data],
  );

  // Validate stored org against memberships
  useEffect(() => {
    if (membershipsQuery.isLoading || !user?.id) return;
    if (memberships.length === 0) {
      if (activeOrgId !== null) {
        writeStoredOrgId(null);
        setActiveOrgId(null);
      }
      return;
    }
    const storedValid = activeOrgId && memberships.some((m) => m.org_id === activeOrgId);
    if (!storedValid) {
      const fallback = memberships[0].org_id;
      writeStoredOrgId(fallback);
      setActiveOrgId(fallback);
    }
  }, [memberships, membershipsQuery.isLoading, activeOrgId, user?.id]);

  // Realtime + JWT refresh on membership change (Pillar 11)
  useEffect(() => {
    if (!user?.id) return;

    if (channelRef.current) {
      supabase.removeChannel(channelRef.current);
      channelRef.current = null;
    }

    const channel = supabase
      .channel(`{{membership_table}}:user:${user.id}`)
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      .on('postgres_changes' as any, {
        event: '*',
        schema: 'public',
        table: '{{membership_table}}',
        filter: `user_id=eq.${user.id}`,
      }, async () => {
        await Promise.all([
          queryClient.invalidateQueries({ queryKey: ['org-memberships', user.id] }),
          supabase.auth.refreshSession(),  // ← Pillar 11: RLS sees new claim
        ]);
      })
      .subscribe();

    channelRef.current = channel;
    return () => {
      if (channelRef.current) {
        supabase.removeChannel(channelRef.current);
        channelRef.current = null;
      }
    };
  }, [user?.id, queryClient]);

  const switchOrg = useCallback((orgId: string) => {
    const target = memberships.find((m) => m.org_id === orgId);
    if (!target) {
      console.warn(`[useOrganization] org ${orgId} not in memberships`);
      return;
    }
    writeStoredOrgId(orgId);
    setActiveOrgId(orgId);

    // Broadcast for stale-channel teardown (Pillar 11)
    if (typeof window !== 'undefined') {
      window.dispatchEvent(new CustomEvent(ORG_SWITCHED_EVENT, { detail: { orgId } }));
    }

    // Invalidate ALL org-scoped query keys — extend per project
    queryClient.invalidateQueries({ queryKey: ['org-members'] });
    queryClient.invalidateQueries({ queryKey: ['org-memberships'] });
    queryClient.invalidateQueries({ queryKey: ['org-audit-log'] });
    // ── ADD YOUR ORG-SCOPED QUERY KEYS BELOW ──
    // queryClient.invalidateQueries({ queryKey: ['propertyEnriched'] });
    // queryClient.invalidateQueries({ queryKey: ['propertyMatches'] });
    // ... continue exhaustively ...
  }, [memberships, queryClient]);

  const activeMembership = useMemo<OrgMembership | null>(
    () => memberships.find((m) => m.org_id === activeOrgId) ?? null,
    [memberships, activeOrgId],
  );

  const activeOrg = activeMembership?.['{{org_table}}'] ?? null;

  return {
    activeOrg,
    activeMembership,
    memberships,
    switchOrg,
    isLoading: membershipsQuery.isLoading,
    error: (membershipsQuery.error as Error | null) ?? null,
  };
}
