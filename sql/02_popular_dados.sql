-- =============================================================================
-- SCRIPT 02: POPULAR DADOS — PROCEDURE + CARGA DE 10.000 PEDIDOS
-- Projeto: Tuning de Consultas em PostgreSQL
-- Estudo de Caso: E-commerce com Controle de Estoque
-- Descrição: Define a stored procedure popular_dados(p_linhas INTEGER)
--            onde p_linhas controla o número de PEDIDOS gerados.
--            As demais tabelas escalam proporcionalmente.
-- Compatibilidade: PostgreSQL 14+
-- =============================================================================

\timing on

-- =============================================================================
-- CRIAÇÃO DA PROCEDURE popular_dados
-- =============================================================================
CREATE OR REPLACE PROCEDURE popular_dados(p_linhas INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    -- ── Arrays de dados sintéticos realistas ─────────────────────────────────
    v_cidades TEXT[] := ARRAY[
        'São Paulo','Rio de Janeiro','Belo Horizonte','Salvador','Fortaleza',
        'Curitiba','Manaus','Recife','Porto Alegre','Belém','Goiânia',
        'Florianópolis','Vitória','Campo Grande','Natal','Teresina',
        'Maceió','João Pessoa','Aracaju','Macapá'
    ];
    v_estados TEXT[] := ARRAY[
        'SP','RJ','MG','BA','CE','PR','AM','PE','RS','PA',
        'GO','SC','ES','MS','RN','PI','AL','PB','SE','AP'
    ];
    v_nomes_p TEXT[] := ARRAY[
        'Ana','Carlos','Fernanda','João','Mariana','Pedro','Luciana','Rafael',
        'Camila','Bruno','Juliana','Thiago','Patricia','Ricardo','Amanda',
        'Felipe','Roberta','Gustavo','Vanessa','Eduardo','Bianca','Leandro',
        'Daniela','Marcelo','Larissa','Rodrigo','Claudia','Anderson','Priscila','Diego'
    ];
    v_sobrenomes TEXT[] := ARRAY[
        'Silva','Santos','Oliveira','Souza','Lima','Costa','Ferreira',
        'Carvalho','Almeida','Nascimento','Araújo','Rodrigues','Gomes',
        'Martins','Pereira','Rocha','Cardoso','Cavalcanti','Barbosa','Mendes',
        'Ribeiro','Monteiro','Teixeira','Azevedo','Correia','Moura','Lemos'
    ];
    v_dominios TEXT[] := ARRAY[
        'gmail.com','hotmail.com','outlook.com','yahoo.com.br','uol.com.br','bol.com.br'
    ];
    v_razoes TEXT[] := ARRAY[
        'Distribuidora','Comércio','Importadora','Indústria','Atacadista',
        'Fornecimentos','Suprimentos','Logística','Trading','Representações'
    ];
    v_sobrenomes_emp TEXT[] := ARRAY[
        'Nacional','Brasil','Nordeste','Sul','Paulista','Carioca',
        'Global','Max','Prime','Plus','Express','Tech','Digital'
    ];
    v_formas_pag TEXT[] := ARRAY[
        'cartao_credito','pix','boleto','cartao_debito','cartao_credito','pix'
    ];
    v_status_dist TEXT[] := ARRAY[
        'entregue','entregue','entregue','entregue','entregue',  -- 50% entregue
        'enviado','enviado',                                      -- 20% enviado
        'confirmado','separando',                                 -- 20% em processo
        'cancelado'                                               -- 10% cancelado
    ];
    v_adjetivos TEXT[] := ARRAY[
        'Ultra','Super','Pro','Smart','Turbo','Max','Lite','Plus',
        'Premium','Advanced','Elite','Flex','Mini','Mega','Neo'
    ];
    v_substantivos TEXT[] := ARRAY[
        'Notebook','Smartphone','Monitor','Teclado','Mouse','Headset',
        'Câmera','Tablet','Impressora','Roteador','Televisão','Geladeira',
        'Máquina de Lavar','Micro-ondas','Liquidificador','Camiseta',
        'Calça','Tênis','Sandália','Mochila','Bicicleta','Patinete',
        'Livro','Caderno','Caneta','Fone','Carregador','Cabo HDMI'
    ];

    -- ── Categorias fixas ──────────────────────────────────────────────────────
    v_categorias TEXT[] := ARRAY[
        'Eletrônicos','Informática','Celulares','Eletrodomésticos','Móveis',
        'Roupas','Calçados','Livros','Brinquedos','Esportes',
        'Beleza','Alimentos','Ferramentas','Automotivo','Papelaria'
    ];

    -- ── Variáveis de trabalho ─────────────────────────────────────────────────
    v_cat_id        INTEGER;
    v_forn_id       INTEGER;
    v_cliente_id    INTEGER;
    v_pedido_id     INTEGER;
    v_produto_id    INTEGER;
    v_preco_custo   NUMERIC(12,2);
    v_preco_venda   NUMERIC(12,2);
    v_qty_itens     INTEGER;
    v_qty_item      INTEGER;
    v_desconto      NUMERIC(5,2);
    v_valor_total   NUMERIC(14,2);
    v_num_clientes  INTEGER;
    v_total_forn    INTEGER := 0;
    v_total_cat     INTEGER := 0;
    v_total_prod    INTEGER := 0;
    v_total_cli     INTEGER := 0;
    v_total_ped     INTEGER := 0;
    v_total_itens   INTEGER := 0;
    v_total_mov     INTEGER := 0;
    v_idx_cidade    INTEGER;

BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Iniciando carga: % pedidos solicitados', p_linhas;
    RAISE NOTICE '====================================================';

    -- =========================================================================
    -- BLOCO 1: Fornecedores
    -- Gera entre 50 e 100 fornecedores com dados sintéticos brasileiros.
    -- =========================================================================
    RAISE NOTICE '[1/6] Inserindo fornecedores...';

    FOR i IN 1..GREATEST(50, LEAST(100, p_linhas / 100)) LOOP
        v_idx_cidade := 1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_cidades, 1))::INTEGER;
        INSERT INTO fornecedores (razao_social, cnpj, cidade, estado, email, telefone, ativo, data_cadastro)
        VALUES (
            v_razoes[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_razoes,1))::INTEGER]
                || ' ' || v_sobrenomes_emp[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_sobrenomes_emp,1))::INTEGER]
                || ' Ltda',
            -- CNPJ no formato XX.XXX.XXX/XXXX-XX (sintético)
            LPAD((FLOOR(RANDOM()*99))::TEXT,2,'0') || '.'
                || LPAD((FLOOR(RANDOM()*999))::TEXT,3,'0') || '.'
                || LPAD((FLOOR(RANDOM()*999))::TEXT,3,'0') || '/'
                || LPAD((FLOOR(RANDOM()*9999))::TEXT,4,'0') || '-'
                || LPAD((FLOOR(RANDOM()*99))::TEXT,2,'0'),
            v_cidades[v_idx_cidade],
            v_estados[v_idx_cidade],
            'contato_' || i || '@fornecedor.com.br',
            '(' || (10 + FLOOR(RANDOM()*79)::INTEGER) || ') 9'
                || LPAD((FLOOR(RANDOM()*99999999))::TEXT,8,'0'),
            RANDOM() > 0.05,
            CURRENT_DATE - (FLOOR(RANDOM() * 2920) || ' days')::INTERVAL
        );
        v_total_forn := v_total_forn + 1;
    END LOOP;
    RAISE NOTICE '[1/6] Fornecedores: %', v_total_forn;

    -- =========================================================================
    -- BLOCO 2: Categorias (fixas e realistas)
    -- =========================================================================
    RAISE NOTICE '[2/6] Inserindo categorias...';

    FOR i IN 1..ARRAY_LENGTH(v_categorias, 1) LOOP
        INSERT INTO categorias (nome, descricao)
        VALUES (
            v_categorias[i],
            'Categoria de produtos: ' || v_categorias[i] || '. Inclui os principais produtos do segmento.'
        )
        ON CONFLICT (nome) DO NOTHING;
        v_total_cat := v_total_cat + 1;
    END LOOP;
    RAISE NOTICE '[2/6] Categorias: %', v_total_cat;

    -- =========================================================================
    -- BLOCO 3: Produtos
    -- Gera proporcional ao volume: entre 200 e 2000 produtos.
    -- =========================================================================
    RAISE NOTICE '[3/6] Inserindo produtos...';

    FOR i IN 1..GREATEST(200, LEAST(2000, p_linhas / 5)) LOOP
        SELECT id INTO v_cat_id FROM categorias
        OFFSET FLOOR(RANDOM() * v_total_cat) LIMIT 1;

        SELECT id INTO v_forn_id FROM fornecedores
        OFFSET FLOOR(RANDOM() * v_total_forn) LIMIT 1;

        v_preco_custo := ROUND((RANDOM() * 1990 + 10)::NUMERIC, 2);
        v_preco_venda := ROUND((v_preco_custo * (1.2 + RANDOM() * 0.6))::NUMERIC, 2); -- margem 20-80%

        INSERT INTO produtos (nome, sku, categoria_id, fornecedor_id,
                              preco_custo, preco_venda, estoque_atual, estoque_minimo,
                              ativo, data_cadastro)
        VALUES (
            v_adjetivos[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_adjetivos,1))::INTEGER]
                || ' ' || v_substantivos[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_substantivos,1))::INTEGER]
                || ' ' || (1000 + i)::TEXT,
            'PROD-' || LPAD(i::TEXT, 5, '0'),
            v_cat_id,
            v_forn_id,
            v_preco_custo,
            v_preco_venda,
            FLOOR(RANDOM() * 500)::INTEGER,
            5 + FLOOR(RANDOM() * 45)::INTEGER,
            RANDOM() > 0.05,
            CURRENT_DATE - (FLOOR(RANDOM() * 1825) || ' days')::INTERVAL
        );
        v_total_prod := v_total_prod + 1;
    END LOOP;
    RAISE NOTICE '[3/6] Produtos: %', v_total_prod;

    -- =========================================================================
    -- BLOCO 4: Clientes
    -- Gera 30% do número de pedidos como base de clientes.
    -- =========================================================================
    RAISE NOTICE '[4/6] Inserindo clientes...';

    v_num_clientes := GREATEST(100, p_linhas / 3);
    FOR i IN 1..v_num_clientes LOOP
        v_idx_cidade := 1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_cidades,1))::INTEGER;
        INSERT INTO clientes (nome, email, cpf, cidade, estado, data_cadastro, ativo)
        VALUES (
            v_nomes_p[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_nomes_p,1))::INTEGER]
                || ' ' || v_sobrenomes[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_sobrenomes,1))::INTEGER],
            'cliente' || i || '_' || SUBSTRING(MD5(RANDOM()::TEXT), 1, 6)
                || '@' || v_dominios[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_dominios,1))::INTEGER],
            LPAD((FLOOR(RANDOM()*999))::TEXT,3,'0') || '.'
                || LPAD((FLOOR(RANDOM()*999))::TEXT,3,'0') || '.'
                || LPAD((FLOOR(RANDOM()*999))::TEXT,3,'0') || '-'
                || LPAD((FLOOR(RANDOM()*99))::TEXT,2,'0'),
            v_cidades[v_idx_cidade],
            v_estados[v_idx_cidade],
            CURRENT_DATE - (FLOOR(RANDOM() * 1825) || ' days')::INTERVAL,
            RANDOM() > 0.08
        );
        v_total_cli := v_total_cli + 1;
        IF MOD(i, 1000) = 0 THEN
            RAISE NOTICE '  ... % clientes inseridos', i;
        END IF;
    END LOOP;
    RAISE NOTICE '[4/6] Clientes: %', v_total_cli;

    -- =========================================================================
    -- BLOCO 5: Pedidos + Itens + Movimentações
    -- Gera p_linhas pedidos, distribuindo entre os clientes existentes.
    -- Para cada item vendido, registra uma saída no estoque.
    -- Intercala entradas de reposição periodicamente.
    -- =========================================================================
    RAISE NOTICE '[5/6] Inserindo pedidos, itens e movimentações...';

    FOR i IN 1..p_linhas LOOP
        -- Selecionar cliente aleatório
        SELECT id INTO v_cliente_id FROM clientes
        OFFSET FLOOR(RANDOM() * v_total_cli) LIMIT 1;

        -- Inserir pedido
        INSERT INTO pedidos (cliente_id, data_pedido, status, forma_pagamento)
        VALUES (
            v_cliente_id,
            NOW() - (FLOOR(RANDOM() * 730) || ' days')::INTERVAL
                  - (FLOOR(RANDOM() * 1440) || ' minutes')::INTERVAL,
            v_status_dist[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_status_dist,1))::INTEGER],
            v_formas_pag[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_formas_pag,1))::INTEGER]
        )
        RETURNING id INTO v_pedido_id;

        v_total_ped   := v_total_ped + 1;
        v_valor_total := 0;

        -- Entre 1 e 5 itens por pedido
        v_qty_itens := 1 + FLOOR(RANDOM() * 5)::INTEGER;

        FOR j IN 1..v_qty_itens LOOP
            SELECT id, preco_venda INTO v_produto_id, v_preco_venda
            FROM produtos
            OFFSET FLOOR(RANDOM() * v_total_prod) LIMIT 1;

            v_qty_item  := 1 + FLOOR(RANDOM() * 5)::INTEGER;
            v_desconto  := ROUND((RANDOM() * 15)::NUMERIC, 2);  -- 0 a 15% de desconto

            INSERT INTO itens_pedido (pedido_id, produto_id, quantidade, preco_unitario, desconto)
            VALUES (v_pedido_id, v_produto_id, v_qty_item, v_preco_venda, v_desconto);

            v_valor_total := v_valor_total
                + (v_qty_item * v_preco_venda * (1 - v_desconto / 100));
            v_total_itens := v_total_itens + 1;

            -- Registrar saída de estoque para itens de pedidos entregues/enviados
            IF RANDOM() > 0.3 THEN
                INSERT INTO movimentacoes_estoque
                    (produto_id, tipo, quantidade, data_movimentacao, pedido_id, observacao)
                SELECT
                    v_produto_id, 'saida', v_qty_item,
                    NOW() - (FLOOR(RANDOM() * 730) || ' days')::INTERVAL,
                    v_pedido_id,
                    'Saída por venda — pedido #' || v_pedido_id;
                v_total_mov := v_total_mov + 1;
            END IF;
        END LOOP;

        -- Atualizar valor_total do pedido
        UPDATE pedidos SET valor_total = ROUND(v_valor_total, 2) WHERE id = v_pedido_id;

        -- A cada 10 pedidos, gerar uma entrada de reposição de estoque aleatória
        IF MOD(i, 10) = 0 THEN
            SELECT id INTO v_produto_id FROM produtos
            OFFSET FLOOR(RANDOM() * v_total_prod) LIMIT 1;

            INSERT INTO movimentacoes_estoque
                (produto_id, tipo, quantidade, data_movimentacao, observacao)
            VALUES (
                v_produto_id, 'entrada',
                10 + FLOOR(RANDOM() * 90)::INTEGER,
                NOW() - (FLOOR(RANDOM() * 730) || ' days')::INTERVAL,
                'Reposição de estoque — pedido ao fornecedor'
            );
            v_total_mov := v_total_mov + 1;
        END IF;

        -- Progresso a cada 1000 pedidos
        IF MOD(i, 1000) = 0 THEN
            RAISE NOTICE '  ... % pedidos processados (itens: %, movs: %)',
                i, v_total_itens, v_total_mov;
        END IF;
    END LOOP;

    -- =========================================================================
    -- BLOCO 6: ANALYZE em todas as tabelas
    -- =========================================================================
    RAISE NOTICE '[6/6] Executando ANALYZE...';
    ANALYZE fornecedores;
    ANALYZE categorias;
    ANALYZE produtos;
    ANALYZE clientes;
    ANALYZE pedidos;
    ANALYZE itens_pedido;
    ANALYZE movimentacoes_estoque;

    RAISE NOTICE '====================================================';
    RAISE NOTICE 'CARGA CONCLUÍDA!';
    RAISE NOTICE '  fornecedores        : %', v_total_forn;
    RAISE NOTICE '  categorias          : %', v_total_cat;
    RAISE NOTICE '  produtos            : %', v_total_prod;
    RAISE NOTICE '  clientes            : %', v_total_cli;
    RAISE NOTICE '  pedidos             : %', v_total_ped;
    RAISE NOTICE '  itens_pedido        : %', v_total_itens;
    RAISE NOTICE '  movimentacoes_estoque: %', v_total_mov;
    RAISE NOTICE '====================================================';
END;
$$;

-- =============================================================================
-- EXECUÇÃO: 10.000 PEDIDOS
-- =============================================================================
\echo ''
\echo 'Executando carga de 10.000 pedidos...'
CALL popular_dados(10000);

\echo ''
\echo '--- Contagem final ---'
SELECT 'fornecedores'          AS tabela, COUNT(*) FROM fornecedores UNION ALL
SELECT 'categorias',                       COUNT(*) FROM categorias   UNION ALL
SELECT 'produtos',                         COUNT(*) FROM produtos      UNION ALL
SELECT 'clientes',                         COUNT(*) FROM clientes      UNION ALL
SELECT 'pedidos',                          COUNT(*) FROM pedidos       UNION ALL
SELECT 'itens_pedido',                     COUNT(*) FROM itens_pedido  UNION ALL
SELECT 'movimentacoes_estoque',            COUNT(*) FROM movimentacoes_estoque
ORDER BY 1;
