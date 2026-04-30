-- NewStylee Barbearia - Sistema de Agendamento
-- Execute no Supabase SQL Editor (Dashboard > SQL Editor > Nova Query)

-- 1. Tabela de agendamentos
CREATE TABLE IF NOT EXISTS bookings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  barber TEXT NOT NULL,
  service TEXT NOT NULL,
  service_price INTEGER NOT NULL,
  extras JSONB DEFAULT '[]',
  date DATE NOT NULL,
  time_slot TEXT NOT NULL,
  people INTEGER DEFAULT 1,
  obs TEXT DEFAULT '',
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')),
  created_at TIMESTAMPTZ DEFAULT now(),
  -- Impede agendamento duplo no mesmo barbeiro/data/horario
  UNIQUE(barber, date, time_slot)
);

-- 2. Indices para consultas rapidas de disponibilidade
CREATE INDEX IF NOT EXISTS idx_bookings_availability
  ON bookings(barber, date, status);

CREATE INDEX IF NOT EXISTS idx_bookings_date
  ON bookings(date);

-- 3. Ativar RLS (Row Level Security)
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- 4. Politicas: qualquer pessoa pode consultar disponibilidade e agendar
CREATE POLICY "Qualquer pessoa pode ver disponibilidade" ON bookings
  FOR SELECT USING (true);

CREATE POLICY "Qualquer pessoa pode agendar" ON bookings
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Qualquer pessoa pode atualizar status" ON bookings
  FOR UPDATE USING (true) WITH CHECK (true);

-- 5. Limpeza automatica: cancelar agendamentos pendentes com mais de 24h (cron opcional)
-- Configure em Dashboard > Database > Extensions > pg_cron
-- SELECT cron.schedule('limpeza-expirados', '0 */6 * * *', $$
--   UPDATE bookings SET status = 'cancelled'
--   WHERE status = 'pending' AND created_at < now() - interval '24 hours';
-- $$);

-- 6. Tabela de produtos
CREATE TABLE IF NOT EXISTS products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  price INTEGER NOT NULL,
  stock INTEGER DEFAULT 0,
  category TEXT DEFAULT 'produto',
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Produtos visíveis" ON products FOR SELECT USING (true);
CREATE POLICY "Produtos inseríveis" ON products FOR INSERT WITH CHECK (true);
CREATE POLICY "Produtos atualizáveis" ON products FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Produtos deletáveis" ON products FOR DELETE USING (true);

-- 7. Tabela de vendas
CREATE TABLE IF NOT EXISTS sales (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id UUID REFERENCES products(id),
  product_name TEXT NOT NULL,
  quantity INTEGER DEFAULT 1,
  unit_price INTEGER NOT NULL,
  total INTEGER NOT NULL,
  barber TEXT NOT NULL,
  customer_name TEXT DEFAULT '',
  customer_phone TEXT DEFAULT '',
  payment_method TEXT DEFAULT 'dinheiro' CHECK (payment_method IN ('dinheiro', 'pix', 'debito', 'credito')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Vendas visíveis" ON sales FOR SELECT USING (true);
CREATE POLICY "Vendas inseríveis" ON sales FOR INSERT WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(created_at);
CREATE INDEX IF NOT EXISTS idx_sales_barber ON sales(barber);

-- 8. Tabela de despesas
CREATE TABLE IF NOT EXISTS expenses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  description TEXT NOT NULL,
  amount INTEGER NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('aluguel', 'produtos', 'equipamentos', 'agua', 'luz', 'internet', 'manutencao', 'marketing', 'impostos', 'salarios', 'outros')),
  payment_method TEXT DEFAULT 'pix' CHECK (payment_method IN ('dinheiro', 'pix', 'debito', 'credito', 'boleto', 'transferencia')),
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  recurring BOOLEAN DEFAULT false,
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Despesas visiveis" ON expenses FOR SELECT USING (true);
CREATE POLICY "Despesas inseriveis" ON expenses FOR INSERT WITH CHECK (true);
CREATE POLICY "Despesas atualizaveis" ON expenses FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Despesas deletaveis" ON expenses FOR DELETE USING (true);

CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category);

-- 9. Tabela de comissoes
CREATE TABLE IF NOT EXISTS commissions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  barber TEXT NOT NULL,
  percentage INTEGER NOT NULL DEFAULT 40,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(barber)
);

ALTER TABLE commissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Comissoes visiveis" ON commissions FOR SELECT USING (true);
CREATE POLICY "Comissoes inseriveis" ON commissions FOR INSERT WITH CHECK (true);
CREATE POLICY "Comissoes atualizaveis" ON commissions FOR UPDATE USING (true) WITH CHECK (true);

-- 10. Tabela de barbeiros (login individual)
CREATE TABLE IF NOT EXISTS barber_accounts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE barber_accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Barber accounts visiveis" ON barber_accounts FOR SELECT USING (true);
CREATE POLICY "Barber accounts inseriveis" ON barber_accounts FOR INSERT WITH CHECK (true);
CREATE POLICY "Barber accounts atualizaveis" ON barber_accounts FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Barber accounts deletaveis" ON barber_accounts FOR DELETE USING (true);

-- 11. Inserir contas de barbeiros (senhas padrao)
INSERT INTO barber_accounts (name, password) VALUES
  ('Barbeiro 1', 'barb01'),
  ('Barbeiro 2', 'barb02'),
  ('Barbeiro 3', 'barb03'),
  ('Barbeiro 4', 'barb04'),
  ('Barbeiro 5', 'barb05'),
  ('Barbeiro 6', 'barb06'),
  ('Barbeiro 7', 'barb07'),
  ('Barbeiro 8', 'barb08')
ON CONFLICT (name) DO NOTHING;

-- 12. Inserir comissoes padrao (40%)
INSERT INTO commissions (barber, percentage) VALUES
  ('Barbeiro 1', 40), ('Barbeiro 2', 40), ('Barbeiro 3', 40), ('Barbeiro 4', 40),
  ('Barbeiro 5', 40), ('Barbeiro 6', 40), ('Barbeiro 7', 40), ('Barbeiro 8', 40)
ON CONFLICT (barber) DO NOTHING;

-- 13. Tabela de notas/observacoes de clientes (CRM)
CREATE TABLE IF NOT EXISTS customer_notes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_phone TEXT UNIQUE NOT NULL,
  customer_name TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  birthday TEXT DEFAULT '',
  tags TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE customer_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Notas visiveis" ON customer_notes FOR SELECT USING (true);
CREATE POLICY "Notas inseriveis" ON customer_notes FOR INSERT WITH CHECK (true);
CREATE POLICY "Notas atualizaveis" ON customer_notes FOR UPDATE USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_customer_notes_phone ON customer_notes(customer_phone);

-- 14. Tabela de planos/assinaturas
CREATE TABLE IF NOT EXISTS plans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  price INTEGER NOT NULL,
  description TEXT DEFAULT '',
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Planos visiveis" ON plans FOR SELECT USING (true);
CREATE POLICY "Planos inseriveis" ON plans FOR INSERT WITH CHECK (true);
CREATE POLICY "Planos atualizaveis" ON plans FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Planos deletaveis" ON plans FOR DELETE USING (true);

-- 15. Tabela de assinaturas de clientes
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  plan_id UUID REFERENCES plans(id),
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'expired', 'pending')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Assinaturas visiveis" ON subscriptions FOR SELECT USING (true);
CREATE POLICY "Assinaturas inseriveis" ON subscriptions FOR INSERT WITH CHECK (true);
CREATE POLICY "Assinaturas atualizaveis" ON subscriptions FOR UPDATE USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_phone ON subscriptions(customer_phone);

-- 16. Visualizacao da agenda do dia (util para os barbeiros)
CREATE OR REPLACE VIEW agenda_do_dia AS
SELECT
  barber AS barbeiro,
  time_slot AS horario,
  service AS servico,
  customer_name AS cliente,
  customer_phone AS telefone,
  people AS pessoas,
  status
FROM bookings
WHERE date = CURRENT_DATE
  AND status IN ('pending', 'confirmed')
ORDER BY time_slot;
