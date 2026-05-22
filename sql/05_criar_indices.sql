-- =============================================================================
-- SCRIPT 05: CRIAÇÃO DE ÍNDICES ESTRATÉGICOS
-- Projeto: Tuning de Consultas em PostgreSQL
-- Estudo de Caso: E-commerce com Controle de Estoque
-- Descrição: Cria 21 índices estratégicos sobre as 6 tabelas do modelo,
--            cobrindo as necessidades das 6 consultas de teste e operações
--            comuns de e-commerce. Cada índice é comentado com sua finalidade.
-- Compatibilidade: PostgreSQL 14+
-- =============================================================================

\timing on

\echo '============================================================'
\echo 'Criando índices estratégicos...'
\echo '============================================================'

-- =============================================================================
-- FORNECEDORES
-- =============================================================================

-- Beneficia: Consultas que filtram fornecedores ativos (Consulta 3 indiretamente)
DROP INDEX IF EXISTS idx_fornecedores_ativo;
CREATE INDEX idx_fornecedores_ativo ON fornecedores(ativo);
COMMENT ON INDEX idx_fornecedores_ativo IS 'Filtra fornecedores ativos em listagens e JOINs com produtos';
\echo 'idx_fornecedores_ativo criado.'

-- Beneficia: Relatórios regionais de fornecedores por estado
DROP INDEX IF EXISTS idx_fornecedores_estado;
CREATE INDEX idx_fornecedores_estado ON fornecedores(estado);
COMMENT ON INDEX idx_fornecedores_estado IS 'Filtra e agrupa fornecedores por estado (UF)';
\echo 'idx_fornecedores_estado criado.'

-- =============================================================================
-- PRODUTOS
-- =============================================================================

-- Beneficia: Consulta 1 (JOIN categorias → produtos) e Consulta 5 (JOIN produtos)
-- CRÍTICO: FK sem índice força Sequential Scan em produtos para cada linha de categorias
DROP INDEX IF EXISTS idx_produtos_categoria_id;
CREATE INDEX idx_produtos_categoria_id ON produtos(categoria_id);
COMMENT ON INDEX idx_produtos_categoria_id IS 'FK para categorias — essencial para JOINs e filtros por categoria (Consulta 1, 5)';
\echo 'idx_produtos_categoria_id criado.'

-- Beneficia: Consulta 3 (JOIN fornecedores → produtos)
DROP INDEX IF EXISTS idx_produtos_fornecedor_id;
CREATE INDEX idx_produtos_fornecedor_id ON produtos(fornecedor_id);
COMMENT ON INDEX idx_produtos_fornecedor_id IS 'FK para fornecedores — necessário para JOINs de estoque com fornecedor (Consulta 3)';
\echo 'idx_produtos_fornecedor_id criado.'

-- Beneficia: Consulta 1 (filtro p.ativo = TRUE)
DROP INDEX IF EXISTS idx_produtos_ativo;
CREATE INDEX idx_produtos_ativo ON produtos(ativo);
COMMENT ON INDEX idx_produtos_ativo IS 'Filtra produtos ativos no catálogo — evita mostrar produtos descontinuados';
\echo 'idx_produtos_ativo criado.'

-- Beneficia: Consulta 1 (estoque_atual > 0) e Consulta 3 (estoque_atual <= estoque_minimo)
DROP INDEX IF EXISTS idx_produtos_estoque_atual;
CREATE INDEX idx_produtos_estoque_atual ON produtos(estoque_atual);
COMMENT ON INDEX idx_produtos_estoque_atual IS 'Filtra por disponibilidade de estoque (Consulta 1) e reposição (Consulta 3)';
\echo 'idx_produtos_estoque_atual criado.'

-- Beneficia: Busca de produto por SKU (consulta direta, não nos scripts de teste mas crítica em prod)
DROP INDEX IF EXISTS idx_produtos_sku;
CREATE INDEX idx_produtos_sku ON produtos(sku);
COMMENT ON INDEX idx_produtos_sku IS 'Lookup rápido por SKU — código de barras, integração com ERP e busca interna';
\echo 'idx_produtos_sku criado.'

-- ÍNDICE COMPOSTO: Cobre a Consulta 1 completamente com um único índice
-- O otimizador pode usar este índice para filtrar por categoria_id, ativo E
-- estoque_atual simultaneamente, em vez de três índices separados com Bitmap AND.
DROP INDEX IF EXISTS idx_produtos_categoria_ativo_estoque;
CREATE INDEX idx_produtos_categoria_ativo_estoque ON produtos(categoria_id, ativo, estoque_atual);
COMMENT ON INDEX idx_produtos_categoria_ativo_estoque IS
    'Índice composto — cobre a Consulta 1 (categoria + ativo + estoque > 0) em um único acesso ao índice';
\echo 'idx_produtos_categoria_ativo_estoque criado.'

-- =============================================================================
-- CLIENTES
-- =============================================================================

-- Beneficia: Relatórios regionais e segmentação por estado
DROP INDEX IF EXISTS idx_clientes_estado;
CREATE INDEX idx_clientes_estado ON clientes(estado);
COMMENT ON INDEX idx_clientes_estado IS 'Segmentação geográfica de clientes por estado (relatórios regionais)';
\echo 'idx_clientes_estado criado.'

-- Beneficia: Filtros de clientes ativos em operações de marketing
DROP INDEX IF EXISTS idx_clientes_ativo;
CREATE INDEX idx_clientes_ativo ON clientes(ativo);
COMMENT ON INDEX idx_clientes_ativo IS 'Filtra contas ativas para envio de comunicações de marketing';
\echo 'idx_clientes_ativo criado.'

-- =============================================================================
-- PEDIDOS
-- =============================================================================

-- FK sem índice causa Sequential Scan em pedidos para cada cliente.
-- CRÍTICO para a Consulta 6 (CTE agrupa por cliente_id) e histórico de cliente.
DROP INDEX IF EXISTS idx_pedidos_cliente_id;
CREATE INDEX idx_pedidos_cliente_id ON pedidos(cliente_id);
COMMENT ON INDEX idx_pedidos_cliente_id IS 'FK para clientes — necessário para histórico de pedidos por cliente (Consulta 6)';
\echo 'idx_pedidos_cliente_id criado.'

-- Fundamental para a Consulta 2 (filtro BETWEEN em data_pedido)
-- Permite Bitmap Index Scan em vez de Sequential Scan em toda a tabela
DROP INDEX IF EXISTS idx_pedidos_data_pedido;
CREATE INDEX idx_pedidos_data_pedido ON pedidos(data_pedido);
COMMENT ON INDEX idx_pedidos_data_pedido IS 'Filtra pedidos por período (Consulta 2) — elimina Sequential Scan na tabela maior';
\echo 'idx_pedidos_data_pedido criado.'

-- Beneficia: Consulta 2 (status = entregue), Consulta 5 (status = entregue), Consulta 6 (status != cancelado)
DROP INDEX IF EXISTS idx_pedidos_status;
CREATE INDEX idx_pedidos_status ON pedidos(status);
COMMENT ON INDEX idx_pedidos_status IS 'Filtra por status do pedido — usado em quase todas as consultas analíticas';
\echo 'idx_pedidos_status criado.'

-- ÍNDICE COMPOSTO: Cobre a Consulta 2 com um único acesso (status + data_pedido)
-- O otimizador pode usar este índice para filtrar status E data simultaneamente
DROP INDEX IF EXISTS idx_pedidos_status_data;
CREATE INDEX idx_pedidos_status_data ON pedidos(status, data_pedido);
COMMENT ON INDEX idx_pedidos_status_data IS
    'Índice composto — cobre a Consulta 2 (status=entregue AND data BETWEEN) em um único scan';
\echo 'idx_pedidos_status_data criado.'

-- =============================================================================
-- ITENS_PEDIDO
-- =============================================================================

-- CRÍTICO: FK sem índice causa Sequential Scan em itens_pedido para cada pedido.
-- A tabela itens_pedido tende a ser a maior — com 1M pedidos × 3,5 itens médios,
-- tem 3,5M registros. Sem este índice, qualquer JOIN de pedidos para itens é lento.
DROP INDEX IF EXISTS idx_itens_pedido_pedido_id;
CREATE INDEX idx_itens_pedido_pedido_id ON itens_pedido(pedido_id);
COMMENT ON INDEX idx_itens_pedido_pedido_id IS 'FK para pedidos — essencial para JOINs (Consulta 5) e detalhe de pedido';
\echo 'idx_itens_pedido_pedido_id criado.'

-- Beneficia: Consulta 5 (agregar itens por produto) e relatórios de venda por produto
DROP INDEX IF EXISTS idx_itens_pedido_produto_id;
CREATE INDEX idx_itens_pedido_produto_id ON itens_pedido(produto_id);
COMMENT ON INDEX idx_itens_pedido_produto_id IS 'FK para produtos — agregar vendas por produto (Consulta 5)';
\echo 'idx_itens_pedido_produto_id criado.'

-- =============================================================================
-- MOVIMENTACOES_ESTOQUE
-- =============================================================================

-- MAIS CRÍTICO: Consulta 4 filtra por produto_id nesta tabela gigante.
-- Sem índice, cada consulta de histórico de produto varre TODOS os registros.
DROP INDEX IF EXISTS idx_movimentacoes_produto_id;
CREATE INDEX idx_movimentacoes_produto_id ON movimentacoes_estoque(produto_id);
COMMENT ON INDEX idx_movimentacoes_produto_id IS 'Filtra movimentações de um produto específico (Consulta 4) — elimina Full Scan em tabela massiva';
\echo 'idx_movimentacoes_produto_id criado.'

-- Beneficia: Consultas de movimentações por período (auditoria, reconciliação)
DROP INDEX IF EXISTS idx_movimentacoes_data;
CREATE INDEX idx_movimentacoes_data ON movimentacoes_estoque(data_movimentacao);
COMMENT ON INDEX idx_movimentacoes_data IS 'Filtra movimentações por período — auditoria e relatórios temporais';
\echo 'idx_movimentacoes_data criado.'

-- Beneficia: Filtros por tipo de movimentação (apenas entradas, apenas saídas)
DROP INDEX IF EXISTS idx_movimentacoes_tipo;
CREATE INDEX idx_movimentacoes_tipo ON movimentacoes_estoque(tipo);
COMMENT ON INDEX idx_movimentacoes_tipo IS 'Filtra por tipo (entrada/saida/ajuste/devolucao) — relatórios de compras vs vendas';
\echo 'idx_movimentacoes_tipo criado.'

-- Beneficia: Rastreamento de movimentações ligadas a um pedido específico
DROP INDEX IF EXISTS idx_movimentacoes_pedido_id;
CREATE INDEX idx_movimentacoes_pedido_id ON movimentacoes_estoque(pedido_id);
COMMENT ON INDEX idx_movimentacoes_pedido_id IS 'FK para pedidos — relaciona movimentações a um pedido (devolução, saída por venda)';
\echo 'idx_movimentacoes_pedido_id criado.'

-- ÍNDICE COMPOSTO: Cobre a Consulta 4 completamente (produto_id + data DESC)
-- Permite que o ORDER BY data_movimentacao DESC seja satisfeito pelo índice,
-- eliminando o Sort e resultando em Index Scan Backward.
DROP INDEX IF EXISTS idx_movimentacoes_produto_data;
CREATE INDEX idx_movimentacoes_produto_data
    ON movimentacoes_estoque(produto_id, data_movimentacao DESC);
COMMENT ON INDEX idx_movimentacoes_produto_data IS
    'Índice composto — cobre a Consulta 4 (produto_id + ORDER BY data DESC) sem Sort adicional';
\echo 'idx_movimentacoes_produto_data criado.'

-- =============================================================================
-- VERIFICAÇÃO FINAL
-- =============================================================================
\echo ''
\echo '============================================================'
\echo 'Todos os 21 índices criados!'
\echo '============================================================'

SELECT
    i.indexname                                                            AS indice,
    i.tablename                                                            AS tabela,
    pg_size_pretty(pg_relation_size(i.indexname::TEXT::REGCLASS))         AS tamanho
FROM pg_indexes i
WHERE i.schemaname = 'public' AND i.indexname LIKE 'idx_%'
ORDER BY i.tablename, i.indexname;

-- Atualizar estatísticas para o otimizador usar os novos índices corretamente
ANALYZE;
\echo 'ANALYZE executado — estatísticas atualizadas.'
