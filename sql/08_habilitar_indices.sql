-- =============================================================================
-- SCRIPT 08: REABILITAR USO DE ÍNDICES
-- Projeto: Tuning de Consultas em PostgreSQL
-- Estudo de Caso: E-commerce com Controle de Estoque
-- Descrição: Restaura os parâmetros do planejador para seus valores padrão,
--            reabilitando todos os métodos de acesso via índice.
-- Compatibilidade: PostgreSQL 14+
-- =============================================================================

\timing on

\echo '============================================================'
\echo 'REABILITANDO USO DE ÍNDICES'
\echo '============================================================'

SET enable_indexscan     = ON;
\echo 'enable_indexscan = ON'

SET enable_bitmapscan    = ON;
\echo 'enable_bitmapscan = ON'

SET enable_indexonlyscan = ON;
\echo 'enable_indexonlyscan = ON'

\echo ''
\echo 'Atualizando estatísticas em todas as tabelas...'

ANALYZE fornecedores;
ANALYZE categorias;
ANALYZE produtos;
ANALYZE clientes;
ANALYZE pedidos;
ANALYZE itens_pedido;
ANALYZE movimentacoes_estoque;

\echo 'ANALYZE concluído.'

\echo ''
\echo '============================================================'
\echo 'ÍNDICES REABILITADOS!'
\echo '============================================================'

SELECT name, setting FROM pg_settings
WHERE name IN ('enable_indexscan','enable_bitmapscan','enable_indexonlyscan')
ORDER BY name;

\echo ''
\echo 'Execute o script 06 para medir os tempos com índices ativos.'
