-- 반드시 새 Supabase 프로젝트의 SQL Editor에서 한 번만 실행하세요.
-- 시험용 설계. 실제 개인정보·업무자료 사용 전 보안 검토가 필요합니다.
create extension if not exists pgcrypto;
create table public.sites (
 id uuid primary key default gen_random_uuid(), name text not null, client text not null,
 work text not null default '', manager text not null default '', status text not null default '진행 중'
);
create table public.profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 role text not null check(role in ('hq','site')), site_id uuid references public.sites(id),
 check ((role = 'hq' and site_id is null) or (role = 'site' and site_id is not null))
);
create table public.labor (
 id uuid primary key default gen_random_uuid(), site_id uuid not null references public.sites(id),
 month text not null check(month ~ '^\d{4}-(0[1-9]|1[0-2])$'),
 people integer not null check(people >= 0), days numeric(10,1) not null check(days >= 0),
 memo text not null default '', unique(site_id,month)
);
create table public.payments (
 id uuid primary key default gen_random_uuid(), site_id uuid not null references public.sites(id),
 month text not null check(month ~ '^\d{4}-(0[1-9]|1[0-2])$'),
 claim bigint not null check(claim >= 0), received bigint not null check(received >= 0 and received <= claim),
 memo text not null default '', unique(site_id,month)
);
create table public.notices (
 id uuid primary key default gen_random_uuid(), title text not null, body text not null,
 created_at timestamptz not null default now()
);
-- 권한 정보는 관리자만 서버에서 생성하며 클라이언트에서 변경할 수 없습니다.
create function public.erp_is_hq() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where user_id = (select auth.uid()) and role='hq')
$$;
create function public.erp_can_site(s uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where user_id = (select auth.uid()) and (role='hq' or (role='site' and site_id=s)))
$$;
revoke all on function public.erp_is_hq() from public;
revoke all on function public.erp_can_site(uuid) from public;
grant execute on function public.erp_is_hq(), public.erp_can_site(uuid) to authenticated;
alter table public.sites enable row level security;
alter table public.profiles enable row level security;
alter table public.labor enable row level security;
alter table public.payments enable row level security;
alter table public.notices enable row level security;
revoke all on public.sites, public.profiles, public.labor, public.payments, public.notices from anon, authenticated;
grant select on public.profiles to authenticated;
grant select,insert,update on public.sites, public.labor, public.payments, public.notices to authenticated;
create policy profile_read on public.profiles for select to authenticated using (user_id=(select auth.uid()) or (select public.erp_is_hq()));
create policy site_read on public.sites for select to authenticated using (public.erp_can_site(id));
create policy site_insert on public.sites for insert to authenticated with check ((select public.erp_is_hq()));
create policy site_update on public.sites for update to authenticated using ((select public.erp_is_hq())) with check ((select public.erp_is_hq()));
create policy labor_read on public.labor for select to authenticated using (public.erp_can_site(site_id));
create policy labor_insert on public.labor for insert to authenticated with check (public.erp_can_site(site_id));
create policy labor_update on public.labor for update to authenticated using (public.erp_can_site(site_id)) with check (public.erp_can_site(site_id));
create policy payment_read on public.payments for select to authenticated using (public.erp_can_site(site_id));
create policy payment_insert on public.payments for insert to authenticated with check (public.erp_can_site(site_id));
create policy payment_update on public.payments for update to authenticated using (public.erp_can_site(site_id)) with check (public.erp_can_site(site_id));
create policy notice_read on public.notices for select to authenticated using (exists(select 1 from public.profiles where user_id=(select auth.uid())));
create policy notice_insert on public.notices for insert to authenticated with check ((select public.erp_is_hq()));
create policy notice_update on public.notices for update to authenticated using ((select public.erp_is_hq())) with check ((select public.erp_is_hq()));
insert into public.sites(id,name,client,work,manager) values
 ('11111111-1111-4111-8111-111111111111','양산 주거시설 신축공사','GS건설','철근콘크리트','현장 관리자'),
 ('22222222-2222-4222-8222-222222222222','부산 업무시설 신축공사','현대건설','철근콘크리트','현장 관리자');
insert into public.notices(title,body) values ('이번 달 현장 실적 입력 안내','각 현장 관리자는 이번 달 인력과 기성 현황을 입력해 주세요. 이 공지는 샘플입니다.');
