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

-- 8. Visualizacao da agenda do dia (util para os barbeiros)
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
