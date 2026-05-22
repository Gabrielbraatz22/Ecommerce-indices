-- =============================================================================
-- TUNING DE CONSULTAS EM PostgreSQL
-- Estudo de Caso: E-commerce com Controle de Estoque
-- Roteiro completo em um único script — PostgreSQL 14+
--
-- PASSOS:
--   1. Criar as 7 tabelas
--   2. Popular ~10.000 pedidos
--   3. Consultas SEM índice  → anote os tempos
--   4. Criar índices estratégicos
--   5. Consultas COM índice  → compare os ganhos
--   6. Outras técnicas: VACUUM, Particionamento, Materialized View,
--                       Índice Parcial, Índice de Cobertura, Memória
-- =============================================================================

\timing on

-- =============================================================================
-- PASSO 1: CRIAR AS TABELAS
-- =============================================================================

DROP TABLE IF EXISTS movimentacoes_estoque CASCADE;
DROP TABLE IF EXISTS itens_pedido          CASCADE;
DROP TABLE IF EXISTS pedidos               CASCADE;
DROP TABLE IF EXISTS clientes              CASCADE;
DROP TABLE IF EXISTS produtos              CASCADE;
DROP TABLE IF EXISTS categorias            CASCADE;
DROP TABLE IF EXISTS fornecedores          CASCADE;

CREATE TABLE fornecedores (
    id            SERIAL       PRIMARY KEY,
    razao_social  VARCHAR(150) NOT NULL,
    cnpj          VARCHAR(18)  NOT NULL UNIQUE,
    cidade        VARCHAR(100),
    estado        CHAR(2),
    email         VARCHAR(120),
    telefone      VARCHAR(20),
    ativo         BOOLEAN      NOT NULL DEFAULT TRUE,
    data_cadastro DATE         NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE categorias (
    id        SERIAL      PRIMARY KEY,
    nome      VARCHAR(80) NOT NULL UNIQUE,
    descricao TEXT
);

CREATE TABLE produtos (
    id             SERIAL        PRIMARY KEY,
    nome           VARCHAR(200)  NOT NULL,
    sku            VARCHAR(50)   NOT NULL UNIQUE,
    categoria_id   INTEGER       NOT NULL REFERENCES categorias(id),
    fornecedor_id  INTEGER       NOT NULL REFERENCES fornecedores(id),
    preco_custo    NUMERIC(12,2) NOT NULL CHECK (preco_custo  >= 0),
    preco_venda    NUMERIC(12,2) NOT NULL CHECK (preco_venda  >= 0),
    estoque_atual  INTEGER       NOT NULL DEFAULT 0  CHECK (estoque_atual  >= 0),
    estoque_minimo INTEGER       NOT NULL DEFAULT 5  CHECK (estoque_minimo >= 0),
    ativo          BOOLEAN       NOT NULL DEFAULT TRUE,
    data_cadastro  DATE          NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE clientes (
    id            SERIAL       PRIMARY KEY,
    nome          VARCHAR(150) NOT NULL,
    email         VARCHAR(120) NOT NULL UNIQUE,
    cpf           VARCHAR(14)  UNIQUE,
    cidade        VARCHAR(100),
    estado        CHAR(2),
    data_cadastro DATE         NOT NULL DEFAULT CURRENT_DATE,
    ativo         BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE pedidos (
    id              SERIAL        PRIMARY KEY,
    cliente_id      INTEGER       NOT NULL REFERENCES clientes(id),
    data_pedido     TIMESTAMP     NOT NULL DEFAULT NOW(),
    status          VARCHAR(30)   NOT NULL DEFAULT 'pendente'
                    CHECK (status IN ('pendente','confirmado','separando',
                                      'enviado','entregue','cancelado')),
    valor_total     NUMERIC(14,2) CHECK (valor_total IS NULL OR valor_total >= 0),
    forma_pagamento VARCHAR(30)
);

CREATE TABLE itens_pedido (
    id             SERIAL        PRIMARY KEY,
    pedido_id      INTEGER       NOT NULL REFERENCES pedidos(id),
    produto_id     INTEGER       NOT NULL REFERENCES produtos(id),
    quantidade     INTEGER       NOT NULL CHECK (quantidade     >  0),
    preco_unitario NUMERIC(12,2) NOT NULL CHECK (preco_unitario >= 0),
    desconto       NUMERIC(5,2)  NOT NULL DEFAULT 0
                   CHECK (desconto BETWEEN 0 AND 100)
);

CREATE TABLE movimentacoes_estoque (
    id                SERIAL      PRIMARY KEY,
    produto_id        INTEGER     NOT NULL REFERENCES produtos(id),
    tipo              VARCHAR(20) NOT NULL
                      CHECK (tipo IN ('entrada','saida','ajuste','devolucao')),
    quantidade        INTEGER     NOT NULL,
    data_movimentacao TIMESTAMP   NOT NULL DEFAULT NOW(),
    pedido_id         INTEGER     REFERENCES pedidos(id),
    observacao        TEXT
);

-- =============================================================================
-- PASSO 2: POPULAR OS DADOS  (~10.000 pedidos)
-- =============================================================================

-- Categorias (10 fixas)
INSERT INTO categorias (nome) VALUES
    ('Eletrônicos'), ('Informática'), ('Celulares'), ('Eletrodomésticos'),
    ('Móveis'),      ('Roupas'),      ('Calçados'),  ('Livros'),
    ('Esportes'),    ('Beleza');

-- Fornecedores (30 registros via generate_series)
INSERT INTO fornecedores (razao_social, cnpj, cidade, estado, email, telefone)
SELECT
    'Distribuidora '
        || (ARRAY['Nacional','Brasil','Sul','Paulista','Global'])[1 + (i-1) % 5]
        || ' Ltda',
    LPAD(i::TEXT, 2,'0') || '.' || LPAD((i*7)::TEXT,3,'0') || '.'
        || LPAD((i*13)::TEXT,3,'0') || '/0001-' || LPAD((i*3)::TEXT,2,'0'),
    (ARRAY['São Paulo','Rio de Janeiro','Curitiba','Belo Horizonte','Porto Alegre'])[1+(i-1)%5],
    (ARRAY['SP','RJ','PR','MG','RS'])[1+(i-1)%5],
    'contato' || i || '@fornecedor.com',
    '(' || (11 + i % 9) || ') 9' || LPAD((i * 9999)::TEXT, 8, '0')
FROM generate_series(1, 30) AS i;

-- Produtos (500 registros)
INSERT INTO produtos (nome, sku, categoria_id, fornecedor_id,
                      preco_custo, preco_venda, estoque_atual, estoque_minimo, ativo)
SELECT
    (ARRAY['Ultra','Super','Pro','Smart','Max'])[1+(i-1)%5]
        || ' '
        || (ARRAY['Notebook','Smartphone','Monitor','Teclado','Mouse',
                  'Headset','Câmera','Tablet','Impressora','Roteador'])[1+(i-1)%10]
        || ' ' || i,
    'PROD-' || LPAD(i::TEXT, 5, '0'),
    1 + (i-1) % 10,
    1 + (i-1) % 30,
    ROUND((50  + RANDOM() * 1950)::NUMERIC, 2),
    ROUND((100 + RANDOM() * 2900)::NUMERIC, 2),
    (RANDOM() * 500)::INT,
    5 + (RANDOM() * 45)::INT,
    RANDOM() > 0.05
FROM generate_series(1, 500) AS i;

-- Clientes (3.000 registros)
INSERT INTO clientes (nome, email, cidade, estado, data_cadastro, ativo)
SELECT
    (ARRAY['Ana','Carlos','Fernanda','João','Mariana',
           'Pedro','Luciana','Rafael','Camila','Bruno'])[1+(i-1)%10]
        || ' '
        || (ARRAY['Silva','Santos','Oliveira','Souza','Lima',
                  'Costa','Ferreira','Carvalho','Almeida','Rocha'])[1+(i-1)%10],
    'cliente' || i || '@email.com',
    (ARRAY['São Paulo','Rio de Janeiro','Curitiba','Belo Horizonte','Porto Alegre'])[1+(i-1)%5],
    (ARRAY['SP','RJ','PR','MG','RS'])[1+(i-1)%5],
    CURRENT_DATE - (RANDOM() * 1825)::INT,
    RANDOM() > 0.08
FROM generate_series(1, 3000) AS i;

-- Procedure: gera pedidos + itens + movimentações de estoque
CREATE OR REPLACE PROCEDURE gerar_pedidos(p_total INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_cli   INTEGER;
    v_ped   INTEGER;
    v_prod  INTEGER;
    v_preco NUMERIC(12,2);
    v_qty   INTEGER;
    v_desc  NUMERIC(5,2);
    v_total NUMERIC(14,2);
    v_itens INTEGER;
BEGIN
    FOR i IN 1..p_total LOOP
        -- Selecionar cliente aleatório
        SELECT id INTO v_cli FROM clientes
        OFFSET FLOOR(RANDOM() * 3000)::INT LIMIT 1;

        -- Criar pedido
        INSERT INTO pedidos (cliente_id, data_pedido, status, forma_pagamento)
        VALUES (
            v_cli,
            NOW() - (FLOOR(RANDOM() * 730)::INT || ' days')::INTERVAL,
            (ARRAY['entregue','entregue','entregue',
                   'enviado','confirmado','cancelado'])[1 + FLOOR(RANDOM()*6)::INT],
            (ARRAY['pix','cartao_credito','boleto','cartao_debito'])[1 + FLOOR(RANDOM()*4)::INT]
        ) RETURNING id INTO v_ped;

        -- Entre 1 e 5 itens por pedido
        v_total := 0;
        v_itens := 1 + FLOOR(RANDOM() * 5)::INT;

        FOR j IN 1..v_itens LOOP
            SELECT id, preco_venda INTO v_prod, v_preco
            FROM produtos OFFSET FLOOR(RANDOM() * 500)::INT LIMIT 1;

            v_qty  := 1 + FLOOR(RANDOM() * 5)::INT;
            v_desc := ROUND((RANDOM() * 15)::NUMERIC, 2);

            INSERT INTO itens_pedido (pedido_id, produto_id, quantidade, preco_unitario, desconto)
            VALUES (v_ped, v_prod, v_qty, v_preco, v_desc);

            -- Saída de estoque para cada item
            INSERT INTO movimentacoes_estoque
                (produto_id, tipo, quantidade, data_movimentacao, pedido_id)
            VALUES (v_prod, 'saida', v_qty,
                    NOW() - (FLOOR(RANDOM()*730)::INT || ' days')::INTERVAL, v_ped);

            v_total := v_total + v_qty * v_preco * (1 - v_desc / 100);
        END LOOP;

        UPDATE pedidos SET valor_total = ROUND(v_total, 2) WHERE id = v_ped;

        -- A cada 10 pedidos, entrada de reposição
        IF MOD(i, 10) = 0 THEN
            SELECT id INTO v_prod FROM produtos
            OFFSET FLOOR(RANDOM() * 500)::INT LIMIT 1;

            INSERT INTO movimentacoes_estoque
                (produto_id, tipo, quantidade, data_movimentacao)
            VALUES (v_prod, 'entrada', 10 + FLOOR(RANDOM() * 90)::INT,
                    NOW() - (FLOOR(RANDOM()*730)::INT || ' days')::INTERVAL);
        END IF;
    END LOOP;
END;
$$;

CALL gerar_pedidos(10000);

ANALYZE fornecedores; ANALYZE categorias;  ANALYZE produtos;
ANALYZE clientes;     ANALYZE pedidos;     ANALYZE itens_pedido;
ANALYZE movimentacoes_estoque;

-- Verificar volumes inseridos
SELECT tabela, COUNT(*) AS linhas FROM (
    SELECT 'fornecedores'          AS tabela FROM fornecedores UNION ALL
    SELECT 'categorias'                      FROM categorias   UNION ALL
    SELECT 'produtos'                        FROM produtos      UNION ALL
    SELECT 'clientes'                        FROM clientes      UNION ALL
    SELECT 'pedidos'                         FROM pedidos       UNION ALL
    SELECT 'itens_pedido'                    FROM itens_pedido  UNION ALL
    SELECT 'movimentacoes_estoque'           FROM movimentacoes_estoque
) t GROUP BY tabela ORDER BY tabela;

-- =============================================================================
-- PASSO 3: CONSULTAS SEM ÍNDICE
-- Anote os tempos — vamos comparar com os resultados do PASSO 5.
-- =============================================================================

-- Q1: Produtos por categoria e disponibilidade
--     [Seq Scan em produtos + Hash Join com categorias]
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.id, p.nome, p.sku, p.preco_venda, p.estoque_atual, c.nome AS categoria
FROM produtos p
JOIN categorias c ON c.id = p.categoria_id
WHERE c.nome = 'Eletrônicos' AND p.estoque_atual > 0 AND p.ativo = TRUE
ORDER BY p.preco_venda;

-- Q2: Faturamento diário por período
--     [Seq Scan completo em pedidos — tabela grande!]
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT DATE(data_pedido) AS dia, COUNT(*) AS pedidos,
       SUM(valor_total) AS receita, AVG(valor_total) AS ticket_medio
FROM pedidos
WHERE data_pedido BETWEEN '2024-01-01' AND '2024-06-30' AND status = 'entregue'
GROUP BY DATE(data_pedido) ORDER BY dia;

-- Q3: Produtos com estoque abaixo do mínimo
--     [Full Scan em produtos + Full Scan em fornecedores]
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.nome, p.sku, p.estoque_atual, p.estoque_minimo,
       (p.estoque_minimo - p.estoque_atual) AS deficit,
       f.razao_social, f.email
FROM produtos p
JOIN fornecedores f ON f.id = p.fornecedor_id
WHERE p.estoque_atual <= p.estoque_minimo AND p.ativo = TRUE
ORDER BY deficit DESC;

-- Q4: Histórico de movimentações de um produto
--     [Seq Scan na tabela MAIOR do sistema — caso mais crítico!]
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT m.data_movimentacao, m.tipo, m.quantidade, m.observacao, p.status
FROM movimentacoes_estoque m
LEFT JOIN pedidos p ON p.id = m.pedido_id
WHERE m.produto_id = 250
ORDER BY m.data_movimentacao DESC LIMIT 100;

-- Q5: Ranking de produtos mais vendidos
--     [Hash Joins em 4 tabelas + agregação pesada sem filtro prévio]
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT pr.nome, pr.sku, c.nome AS categoria,
       SUM(i.quantidade)                                     AS total_vendido,
       SUM(i.quantidade * i.preco_unitario * (1 - i.desconto/100)) AS receita
FROM itens_pedido i
JOIN produtos   pr ON pr.id = i.produto_id
JOIN categorias c  ON c.id  = pr.categoria_id
JOIN pedidos    p  ON p.id  = i.pedido_id
WHERE p.status = 'entregue'
GROUP BY pr.id, pr.nome, pr.sku, c.nome
ORDER BY total_vendido DESC LIMIT 20;

-- Q6: Clientes VIP com CTE
--     [CTE materializa pedidos completos, depois Hash Join com clientes]
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH totais AS (
    SELECT cliente_id, COUNT(*) AS total_pedidos,
           SUM(valor_total) AS total_gasto, MAX(data_pedido) AS ultima_compra
    FROM pedidos WHERE status != 'cancelado'
    GROUP BY cliente_id
)
SELECT cl.nome, cl.email, cl.cidade, cl.estado,
       t.total_pedidos, ROUND(t.total_gasto, 2) AS total_gasto,
       RANK() OVER (ORDER BY t.total_gasto DESC) AS ranking_vip
FROM totais t
JOIN clientes cl ON cl.id = t.cliente_id
WHERE t.total_gasto > 1000
ORDER BY t.total_gasto DESC LIMIT 50;

-- =============================================================================
-- PASSO 4: CRIAR ÍNDICES ESTRATÉGICOS
-- =============================================================================

-- PRODUTOS: índice composto cobre Q1 (categoria + ativo + estoque) de uma vez
DROP INDEX IF EXISTS idx_produtos_categoria_ativo_estoque;
CREATE INDEX idx_produtos_categoria_ativo_estoque
    ON produtos(categoria_id, ativo, estoque_atual);

-- PRODUTOS: FK para fornecedores (Q3)
DROP INDEX IF EXISTS idx_produtos_fornecedor_id;
CREATE INDEX idx_produtos_fornecedor_id ON produtos(fornecedor_id);

-- PEDIDOS: índice composto cobre Q2 (status + data_pedido)
DROP INDEX IF EXISTS idx_pedidos_status_data;
CREATE INDEX idx_pedidos_status_data ON pedidos(status, data_pedido);

-- PEDIDOS: FK para clientes (Q6 — CTE por cliente_id)
DROP INDEX IF EXISTS idx_pedidos_cliente_id;
CREATE INDEX idx_pedidos_cliente_id ON pedidos(cliente_id);

-- PEDIDOS: filtro por data isolado (range queries genéricas)
DROP INDEX IF EXISTS idx_pedidos_data_pedido;
CREATE INDEX idx_pedidos_data_pedido ON pedidos(data_pedido);

-- ITENS_PEDIDO: FK para pedidos (Q5 — JOIN pedido_id)
DROP INDEX IF EXISTS idx_itens_pedido_id;
CREATE INDEX idx_itens_pedido_id ON itens_pedido(pedido_id);

-- ITENS_PEDIDO: FK para produtos (Q5 — agregação por produto)
DROP INDEX IF EXISTS idx_itens_produto_id;
CREATE INDEX idx_itens_produto_id ON itens_pedido(produto_id);

-- MOVIMENTACOES_ESTOQUE: O MAIS CRÍTICO
-- Índice composto elimina o Seq Scan E o Sort da Q4 de uma só vez
DROP INDEX IF EXISTS idx_movimentacoes_produto_data;
CREATE INDEX idx_movimentacoes_produto_data
    ON movimentacoes_estoque(produto_id, data_movimentacao DESC);

-- Verificar índices e tamanhos
SELECT tablename AS tabela, indexname AS indice,
       pg_size_pretty(pg_relation_size(indexname::TEXT::REGCLASS)) AS tamanho
FROM pg_indexes
WHERE schemaname = 'public' AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

ANALYZE;

-- =============================================================================
-- PASSO 5: CONSULTAS COM ÍNDICE
-- Compare os planos e tempos com o PASSO 3!
--
-- Dica: para forçar Sequential Scan mesmo com índices criados (útil para
-- repetir a comparação na mesma sessão), use:
--   SET enable_indexscan = OFF; SET enable_bitmapscan = OFF; SET enable_indexonlyscan = OFF;
-- Para restaurar:
--   SET enable_indexscan = ON;  SET enable_bitmapscan = ON;  SET enable_indexonlyscan = ON;
-- =============================================================================

SET enable_indexscan     = ON;
SET enable_bitmapscan    = ON;
SET enable_indexonlyscan = ON;

-- Q1 com índice — idx_produtos_categoria_ativo_estoque  [ganho: ~90-97%]
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.id, p.nome, p.sku, p.preco_venda, p.estoque_atual, c.nome AS categoria
FROM produtos p
JOIN categorias c ON c.id = p.categoria_id
WHERE c.nome = 'Eletrônicos' AND p.estoque_atual > 0 AND p.ativo = TRUE
ORDER BY p.preco_venda;

-- Q2 com índice — idx_pedidos_status_data  [ganho: ~88-95%]
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT DATE(data_pedido) AS dia, COUNT(*) AS pedidos,
       SUM(valor_total) AS receita, AVG(valor_total) AS ticket_medio
FROM pedidos
WHERE data_pedido BETWEEN '2024-01-01' AND '2024-06-30' AND status = 'entregue'
GROUP BY DATE(data_pedido) ORDER BY dia;

-- Q3 com índice — idx_produtos_fornecedor_id  [ganho: ~85-93%]
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.nome, p.sku, p.estoque_atual, p.estoque_minimo,
       (p.estoque_minimo - p.estoque_atual) AS deficit,
       f.razao_social, f.email
FROM produtos p
JOIN fornecedores f ON f.id = p.fornecedor_id
WHERE p.estoque_atual <= p.estoque_minimo AND p.ativo = TRUE
ORDER BY deficit DESC;

-- Q4 com índice — idx_movimentacoes_produto_data  [ganho: ~97-99%! O maior ganho]
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT m.data_movimentacao, m.tipo, m.quantidade, m.observacao, p.status
FROM movimentacoes_estoque m
LEFT JOIN pedidos p ON p.id = m.pedido_id
WHERE m.produto_id = 250
ORDER BY m.data_movimentacao DESC LIMIT 100;

-- Q5 com índice — idx_pedidos_status + idx_itens_*  [ganho: ~70-80%]
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT pr.nome, pr.sku, c.nome AS categoria,
       SUM(i.quantidade)                                     AS total_vendido,
       SUM(i.quantidade * i.preco_unitario * (1 - i.desconto/100)) AS receita
FROM itens_pedido i
JOIN produtos   pr ON pr.id = i.produto_id
JOIN categorias c  ON c.id  = pr.categoria_id
JOIN pedidos    p  ON p.id  = i.pedido_id
WHERE p.status = 'entregue'
GROUP BY pr.id, pr.nome, pr.sku, c.nome
ORDER BY total_vendido DESC LIMIT 20;

-- Q6 com índice — idx_pedidos_cliente_id  [ganho: ~60-70%]
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH totais AS (
    SELECT cliente_id, COUNT(*) AS total_pedidos,
           SUM(valor_total) AS total_gasto, MAX(data_pedido) AS ultima_compra
    FROM pedidos WHERE status != 'cancelado'
    GROUP BY cliente_id
)
SELECT cl.nome, cl.email, cl.cidade, cl.estado,
       t.total_pedidos, ROUND(t.total_gasto, 2) AS total_gasto,
       RANK() OVER (ORDER BY t.total_gasto DESC) AS ranking_vip
FROM totais t
JOIN clientes cl ON cl.id = t.cliente_id
WHERE t.total_gasto > 1000
ORDER BY t.total_gasto DESC LIMIT 50;

-- Índices usados nesta sessão
SELECT relname AS tabela, indexrelname AS indice, idx_scan AS vezes_usado
FROM pg_stat_user_indexes
WHERE schemaname = 'public' AND indexrelname LIKE 'idx_%'
ORDER BY idx_scan DESC;

-- =============================================================================
-- PASSO 6: OUTRAS TÉCNICAS DE OTIMIZAÇÃO
-- =============================================================================

-- ─── TÉCNICA A: VACUUM ANALYZE ────────────────────────────────────────────────
-- Cada UPDATE em pedidos/estoque gera dead tuples (MVCC do PostgreSQL).
-- VACUUM as limpa; ANALYZE atualiza as estatísticas do otimizador de consultas.

SELECT relname AS tabela, n_live_tup AS linhas_vivas, n_dead_tup AS dead_tuples,
       ROUND(n_dead_tup::NUMERIC / NULLIF(n_live_tup + n_dead_tup, 0) * 100, 2) AS pct_dead,
       last_autovacuum
FROM pg_stat_user_tables WHERE schemaname = 'public' ORDER BY n_dead_tup DESC;

VACUUM ANALYZE pedidos;
VACUUM ANALYZE itens_pedido;
VACUUM ANALYZE movimentacoes_estoque;

-- ─── TÉCNICA B: PARTICIONAMENTO POR RANGE ─────────────────────────────────────
-- movimentacoes_estoque cresce sem parar.
-- Com partições por ano, uma consulta de 2024 lê APENAS a partição mov_2024
-- (Partition Pruning) — ignora os demais anos completamente.

DROP TABLE IF EXISTS movimentacoes_particionada CASCADE;

CREATE TABLE movimentacoes_particionada (
    id                SERIAL,
    produto_id        INTEGER     NOT NULL,
    tipo              VARCHAR(20) NOT NULL,
    quantidade        INTEGER     NOT NULL,
    data_movimentacao TIMESTAMP   NOT NULL DEFAULT NOW(),
    pedido_id         INTEGER,
    observacao        TEXT
) PARTITION BY RANGE (data_movimentacao);

CREATE TABLE mov_2022 PARTITION OF movimentacoes_particionada
    FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');
CREATE TABLE mov_2023 PARTITION OF movimentacoes_particionada
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE mov_2024 PARTITION OF movimentacoes_particionada
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE mov_2025 PARTITION OF movimentacoes_particionada
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE INDEX ON movimentacoes_particionada(produto_id, data_movimentacao DESC);

INSERT INTO movimentacoes_particionada
    (produto_id, tipo, quantidade, data_movimentacao, pedido_id, observacao)
SELECT produto_id, tipo, quantidade, data_movimentacao, pedido_id, observacao
FROM movimentacoes_estoque WHERE data_movimentacao >= '2022-01-01';

-- Veja no plano: "Partitions: mov_2024" — as demais são ignoradas
EXPLAIN (ANALYZE, FORMAT TEXT)
SELECT COUNT(*), SUM(quantidade)
FROM movimentacoes_particionada
WHERE data_movimentacao BETWEEN '2024-01-01' AND '2024-12-31' AND tipo = 'saida';

-- Tamanho de cada partição
SELECT c.relname AS particao,
       pg_size_pretty(pg_relation_size(c.oid)) AS tamanho
FROM pg_inherits
JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
JOIN pg_class c      ON pg_inherits.inhrelid  = c.oid
WHERE parent.relname = 'movimentacoes_particionada' ORDER BY c.relname;

-- ─── TÉCNICA C: MATERIALIZED VIEW ─────────────────────────────────────────────
-- Q5 (ranking de produtos) é consultada várias vezes ao dia, mas não precisa
-- de dados em tempo real. Pré-computar torna a resposta instantânea.
-- Atualizar via pg_cron a cada 30 min, por exemplo.

DROP MATERIALIZED VIEW IF EXISTS mv_ranking_produtos;

CREATE MATERIALIZED VIEW mv_ranking_produtos AS
SELECT pr.id, pr.nome, pr.sku, c.nome AS categoria,
       SUM(i.quantidade)                                     AS total_vendido,
       SUM(i.quantidade * i.preco_unitario * (1-i.desconto/100)) AS receita,
       COUNT(DISTINCT i.pedido_id)                           AS num_pedidos,
       NOW()                                                 AS calculado_em
FROM itens_pedido i
JOIN produtos   pr ON pr.id = i.produto_id
JOIN categorias c  ON c.id  = pr.categoria_id
JOIN pedidos    p  ON p.id  = i.pedido_id
WHERE p.status = 'entregue'
GROUP BY pr.id, pr.nome, pr.sku, c.nome
ORDER BY total_vendido DESC
WITH DATA;

CREATE UNIQUE INDEX ON mv_ranking_produtos(id);

-- Instantâneo — lê dados pré-computados em disco
SELECT * FROM mv_ranking_produtos LIMIT 10;

-- Atualizar sem bloquear leituras (agendável via pg_cron):
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ranking_produtos;

-- ─── TÉCNICA D: ÍNDICE PARCIAL ─────────────────────────────────────────────────
-- Pedidos operacionais (pendente/confirmado/separando) são ~30% do total,
-- mas 100% das consultas do setor de logística. Um índice parcial é menor,
-- mais rápido de manter e igualmente eficaz para esse caso de uso.

DROP INDEX IF EXISTS idx_pedidos_ativos_parcial;
CREATE INDEX idx_pedidos_ativos_parcial ON pedidos(data_pedido, cliente_id)
    WHERE status IN ('pendente','confirmado','separando');

-- Comparar tamanho: índice parcial vs índice completo
SELECT indexname,
       pg_size_pretty(pg_relation_size(indexname::TEXT::REGCLASS)) AS tamanho
FROM pg_indexes
WHERE indexname IN ('idx_pedidos_data_pedido','idx_pedidos_ativos_parcial');

EXPLAIN (ANALYZE, FORMAT TEXT)
SELECT id, cliente_id, data_pedido, valor_total
FROM pedidos
WHERE status = 'pendente' AND data_pedido > NOW() - INTERVAL '7 days';

-- ─── TÉCNICA E: ÍNDICE DE COBERTURA (INCLUDE) ─────────────────────────────────
-- A cláusula INCLUDE adiciona colunas ao índice sem indexá-las.
-- O otimizador usa Index-Only Scan: resolve a query sem tocar a tabela.

DROP INDEX IF EXISTS idx_pedidos_status_data_cover;
CREATE INDEX idx_pedidos_status_data_cover
    ON pedidos(status, data_pedido) INCLUDE (valor_total, cliente_id);

-- Veja "Index Only Scan" no plano — nenhum acesso às páginas da tabela
EXPLAIN (ANALYZE, FORMAT TEXT)
SELECT DATE(data_pedido), COUNT(*), SUM(valor_total)
FROM pedidos
WHERE status = 'entregue' AND data_pedido BETWEEN '2024-01-01' AND '2024-06-30'
GROUP BY DATE(data_pedido);

-- ─── TÉCNICA F: CONFIGURAÇÕES DE MEMÓRIA ─────────────────────────────────────
-- Ver valores atuais:
SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name IN (
    'shared_buffers','work_mem','effective_cache_size',
    'maintenance_work_mem','random_page_cost',
    'default_statistics_target','max_parallel_workers_per_gather'
)
ORDER BY name;

-- Recomendações para servidor 8 GB RAM / SSD NVMe:
--   shared_buffers                  = 2GB   (25% da RAM — cache de páginas)
--   work_mem                        = 64MB  (por operação de sort/hash)
--   effective_cache_size            = 6GB   (informa o otimizador sobre o cache do OS)
--   maintenance_work_mem            = 512MB (para VACUUM, CREATE INDEX)
--   random_page_cost                = 1.1   (1.0–2.0 para SSD; padrão 4.0 é para HD)
--   default_statistics_target       = 200   (mais histogramas → planos melhores)
--   max_parallel_workers_per_gather = 4     (paralelismo em queries analíticas)

-- Demonstrar impacto do work_mem (evita temp files em sorts grandes):
SET work_mem = '128MB';
EXPLAIN (ANALYZE, FORMAT TEXT)
WITH totais AS (
    SELECT cliente_id, SUM(valor_total) AS total
    FROM pedidos WHERE status != 'cancelado'
    GROUP BY cliente_id
)
SELECT cl.nome, ROUND(t.total, 2) AS total_gasto
FROM totais t
JOIN clientes cl ON cl.id = t.cliente_id
WHERE t.total > 1000 ORDER BY t.total DESC LIMIT 50;

-- =============================================================================
-- LIMPEZA DOS OBJETOS TEMPORÁRIOS DESTA APRESENTAÇÃO
-- (Descomente se quiser restaurar o ambiente ao estado pós-índices)
-- =============================================================================
-- DROP TABLE             IF EXISTS movimentacoes_particionada CASCADE;
-- DROP MATERIALIZED VIEW IF EXISTS mv_ranking_produtos;
-- DROP INDEX             IF EXISTS idx_pedidos_ativos_parcial;
-- DROP INDEX             IF EXISTS idx_pedidos_status_data_cover;

-- =============================================================================
-- FIM DO SCRIPT
-- =============================================================================
