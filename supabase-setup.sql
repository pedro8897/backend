create table if not exists public.pedidos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  code text unique not null,
  cliente text,
  telefone text,
  itens jsonb not null default '[]'::jsonb,
  total text,
  pagamento text,
  endereco text,
  step integer not null default 0,
  status text not null default 'aguardando_envio_whatsapp',
  desconto text,
  observacoes text,
  created_at timestamptz not null default now()
);

alter table public.pedidos
add column if not exists user_id uuid references auth.users(id);
alter table public.pedidos add column if not exists status text not null default 'aguardando_envio_whatsapp';
alter table public.pedidos add column if not exists desconto text;
alter table public.pedidos add column if not exists observacoes text;

create index if not exists pedidos_user_id_idx on public.pedidos(user_id);
create index if not exists pedidos_status_idx on public.pedidos(status);

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'admin',
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;

create table if not exists public.restaurant_settings (
  id boolean primary key default true,
  nome_restaurante text,
  nome_empresarial text,
  cnpj text,
  telefone text,
  whatsapp text,
  instagram text,
  endereco text,
  area_atendimento text,
  bairros_atendidos jsonb not null default '[]'::jsonb,
  horario_funcionamento jsonb not null default '{}'::jsonb,
  pedido_minimo numeric,
  taxa_entrega numeric,
  prazo_estimado text,
  chave_pix text,
  cartoes_aceitos jsonb not null default '[]'::jsonb,
  formas_pagamento jsonb not null default '[]'::jsonb,
  politica_cancelamento text,
  politica_atendimento text,
  mensagem_padrao_whatsapp text,
  aberto boolean not null default true,
  logotipo text,
  cores_principais jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint restaurant_settings_single_row check (id)
);

create table if not exists public.produtos (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  descricao text,
  categoria text,
  preco_normal numeric not null,
  preco_promocional numeric,
  promocao_ativa boolean not null default false,
  promocao_inicio timestamptz,
  promocao_fim timestamptz,
  imagem text,
  quantidade_pecas integer,
  tamanho_porcao text,
  ingredientes jsonb not null default '[]'::jsonb,
  adicionais jsonb not null default '[]'::jsonb,
  alergenicos jsonb not null default '[]'::jsonb,
  contem_peixe_cru boolean,
  contem_gluten boolean,
  contem_lactose boolean,
  vegetariano boolean,
  vegano boolean,
  picante boolean,
  disponivel boolean not null default true,
  esgotado boolean not null default false,
  destaque boolean not null default false,
  ordem_exibicao integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.restaurant_settings enable row level security;
alter table public.produtos enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.admin_users
    where user_id = auth.uid()
      and role = 'admin'
  );
$$;

alter table public.pedidos enable row level security;

drop policy if exists "Admins podem ver perfil administrativo" on public.admin_users;
create policy "Admins podem ver perfil administrativo"
on public.admin_users for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Configuracoes publicas podem ser lidas" on public.restaurant_settings;
create policy "Configuracoes publicas podem ser lidas"
on public.restaurant_settings for select
to anon, authenticated
using (true);

drop policy if exists "Admins gerenciam configuracoes" on public.restaurant_settings;
create policy "Admins gerenciam configuracoes"
on public.restaurant_settings for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Produtos publicos podem ser lidos" on public.produtos;
create policy "Produtos publicos podem ser lidos"
on public.produtos for select
to anon, authenticated
using (disponivel = true);

drop policy if exists "Admins gerenciam produtos" on public.produtos;
create policy "Admins gerenciam produtos"
on public.produtos for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Pedidos podem ser criados pelo site" on public.pedidos;
create policy "Pedidos podem ser criados pelo site"
on public.pedidos for insert
to anon, authenticated
with check (
  status = 'aguardando_envio_whatsapp'
  and (
    auth.uid() is null
    or user_id is null
    or user_id = auth.uid()
  )
);

drop policy if exists "Pedidos podem ser lidos pelo site" on public.pedidos;
create policy "Pedidos podem ser lidos pelo site"
on public.pedidos for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "Administracao pode atualizar status" on public.pedidos;
create policy "Administracao pode atualizar status"
on public.pedidos for update
to authenticated
using (public.is_admin())
with check (
  public.is_admin()
  and status in (
    'aguardando_envio_whatsapp',
    'aguardando_confirmacao',
    'confirmado',
    'em_preparo',
    'saiu_para_entrega',
    'entregue',
    'cancelado'
  )
);

drop policy if exists "Administracao pode limpar pedidos" on public.pedidos;
create policy "Administracao pode limpar pedidos"
on public.pedidos for delete
to authenticated
using (public.is_admin());
