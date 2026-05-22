-- =============================================================================
-- SCRIPT 07: DESABILITAR USO DE ÍNDICES (SIMULAÇÃO)
-- Projeto: Tuning de Consultas em PostgreSQL
-- Estudo de Caso: E-commerce com Controle de Estoque
-- Descrição: Simula a ausência de índices para a sessão atual usando
--            parâmetros de configuração do planejador de consultas.
-- ESCOPO: Apenas a sessão atual — outras conexões continuam usando índices.
-- Compatibilidade: PostgreSQL 14+
-- =============================================================================

\timing on

\echo '============================================================'
\echo 'DESABILITANDO USO DE ÍNDICES PARA ESTA SESSÃO'
\echo '============================================================'

-- Desabilita Index Scans (acesso direto ao índice)
SET enable_indexscan = OFF;
\echo 'enable_indexscan = OFF'

-- Desabilita Bitmap Index Scans (scan via mapa de bits de blocos)
SET enable_bitmapscan = OFF;
\echo 'enable_bitmapscan = OFF'

-- Desabilita Index-Only Scans (quando toda a query é resolvida pelo índice)
SET enable_indexonlyscan = OFF;
\echo 'enable_indexonlyscan = OFF'

\echo ''
\echo '============================================================'
\echo 'COMPARATIVO: DISABLE INDEX em diferentes SGBDs'
\echo '============================================================'
\echo ''
\echo 'MySQL / MariaDB:'
\echo '  ALTER TABLE produtos DISABLE KEYS;'
\echo '  ALTER TABLE produtos ENABLE KEYS;'
\echo '  -- Desabilita apenas índices secundários (não PKs e UKs)'
\echo ''
\echo 'Oracle Database:'
\echo '  ALTER INDEX idx_produtos_categoria_id UNUSABLE;'
\echo '  ALTER INDEX idx_produtos_categoria_id REBUILD;'
\echo '  -- Marca o índice como inutilizável permanentemente (até REBUILD)'
\echo ''
\echo 'SQL Server:'
\echo '  ALTER INDEX idx_produtos_categoria_id ON produtos DISABLE;'
\echo '  ALTER INDEX idx_produtos_categoria_id ON produtos REBUILD;'
\echo '  -- Desabilita permanentemente o índice para todas as conexões'
\echo ''
\echo 'PostgreSQL:'
\echo '  Não existe DISABLE INDEX nativo.'
\echo '  Abordagem 1 (sessão): SET enable_indexscan = OFF  ← este script'
\echo '  Abordagem 2 (global): DROP INDEX + CREATE INDEX (mais disruptivo)'
\echo '  POR QUÊ? O MVCC do PostgreSQL mantém índices sempre consistentes.'
\echo '  Desabilitar um índice sem dropá-lo seria complexo com MVCC ativo.'
\echo '============================================================'

\echo ''
\echo 'Configurações aplicadas nesta sessão:'
SELECT name, setting FROM pg_settings
WHERE name IN ('enable_indexscan','enable_bitmapscan','enable_indexonlyscan')
ORDER BY name;

\echo ''
\echo 'Execute as consultas do script 04 agora para obter tempos'
\echo 'com Sequential Scan mesmo que índices existam fisicamente.'
