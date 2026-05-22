-- =============================================================================
-- SCRIPT 03: POPULAR DADOS — 1.000.000 DE PEDIDOS
-- Projeto: Tuning de Consultas em PostgreSQL
-- Estudo de Caso: E-commerce com Controle de Estoque
-- Descrição: Limpa todas as tabelas e popula com 1.000.000 de pedidos,
--            simulando um sistema de e-commerce em escala de produção.
--
-- VOLUME ESPERADO:
--   fornecedores          : ~100
--   categorias            : 15
--   produtos              : ~2.000
--   clientes              : ~333.000
--   pedidos               : 1.000.000
--   itens_pedido          : ~3.500.000
--   movimentacoes_estoque : ~3.600.000 (saídas + entradas de reposição)
--
-- PRÉ-REQUISITO: Script 02_popular_dados.sql deve ter sido executado
--                para que a procedure popular_dados() exista.
--
-- TEMPO ESTIMADO: 15 a 90 minutos dependendo do hardware.
--
-- ATENÇÃO: Todos os dados existentes serão APAGADOS.
-- =============================================================================

\timing on

\echo '============================================================'
\echo 'ATENÇÃO: Todos os dados serão apagados e recarregados com'
\echo '         1.000.000 de pedidos.'
\echo '============================================================'

-- =============================================================================
-- LIMPEZA COMPLETA
-- TRUNCATE CASCADE respeita as FKs automaticamente.
-- RESTART IDENTITY reinicia todos os contadores SERIAL.
-- =============================================================================
TRUNCATE movimentacoes_estoque RESTART IDENTITY CASCADE;
TRUNCATE itens_pedido          RESTART IDENTITY CASCADE;
TRUNCATE pedidos               RESTART IDENTITY CASCADE;
TRUNCATE clientes              RESTART IDENTITY CASCADE;
TRUNCATE produtos              RESTART IDENTITY CASCADE;
TRUNCATE categorias            RESTART IDENTITY CASCADE;
TRUNCATE fornecedores          RESTART IDENTITY CASCADE;

\echo 'Tabelas limpas com sucesso.'

-- =============================================================================
-- CONFIGURAÇÕES DE PERFORMANCE PARA CARGA EM MASSA
-- Aumentar work_mem e desativar synchronous_commit para acelerar inserções.
-- Seguro em ambiente de teste; NUNCA usar synchronous_commit=off em produção
-- sem entender as implicações de perda de dados em falha de hardware.
-- =============================================================================
SET work_mem = '256MB';
SET synchronous_commit = OFF;  -- Acelera inserções (sem risco de dados aqui)

-- =============================================================================
-- EXECUÇÃO DA CARGA
-- =============================================================================
\echo ''
\echo 'Iniciando carga de 1.000.000 de pedidos...'
\echo 'Mensagens de progresso a cada 1.000 pedidos.'

CALL popular_dados(1000000);

-- Restaurar configuração de commit
SET synchronous_commit = ON;

-- =============================================================================
-- VACUUM ANALYZE COMPLETO
-- Após carga massiva, VACUUM limpa dead tuples geradas pelas atualizações
-- de valor_total nos pedidos. ANALYZE atualiza as estatísticas do otimizador.
-- =============================================================================
\echo ''
\echo 'Executando VACUUM ANALYZE em todas as tabelas...'
VACUUM ANALYZE fornecedores;
VACUUM ANALYZE categorias;
VACUUM ANALYZE produtos;
VACUUM ANALYZE clientes;
VACUUM ANALYZE pedidos;
VACUUM ANALYZE itens_pedido;
VACUUM ANALYZE movimentacoes_estoque;

\echo ''
\echo '============================================================'
\echo 'CARGA DE 1.000.000 DE PEDIDOS CONCLUÍDA!'
\echo '============================================================'

-- Verificação com tamanhos reais
SELECT
    c.relname                                            AS tabela,
    to_char(s.n_live_tup, 'FM999,999,999')              AS linhas_vivas,
    pg_size_pretty(pg_total_relation_size(c.oid))        AS tamanho_total
FROM pg_class c
JOIN pg_stat_user_tables s ON s.relid = c.oid
WHERE c.relkind = 'r' AND c.relnamespace = 'public'::REGNAMESPACE
ORDER BY pg_total_relation_size(c.oid) DESC;
