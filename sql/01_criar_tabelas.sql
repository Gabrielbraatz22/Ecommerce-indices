-- =============================================================================
-- SCRIPT 01: CRIAÇÃO DAS TABELAS
-- Projeto: Tuning de Consultas em PostgreSQL
-- Estudo de Caso: E-commerce com Controle de Estoque
-- Descrição: Cria o schema completo com 7 tabelas inter-relacionadas.
-- Compatibilidade: PostgreSQL 14+
-- =============================================================================

\timing on

-- Remover tabelas em ordem reversa de dependência (respeita FKs)
DROP TABLE IF EXISTS movimentacoes_estoque CASCADE;
DROP TABLE IF EXISTS itens_pedido          CASCADE;
DROP TABLE IF EXISTS pedidos               CASCADE;
DROP TABLE IF EXISTS clientes              CASCADE;
DROP TABLE IF EXISTS produtos              CASCADE;
DROP TABLE IF EXISTS categorias            CASCADE;
DROP TABLE IF EXISTS fornecedores          CASCADE;

-- =============================================================================
-- TABELA: fornecedores
-- Cadastro de empresas que fornecem os produtos vendidos na plataforma.
-- É a raiz da cadeia de suprimentos: produto → fornecedor.
-- =============================================================================
CREATE TABLE fornecedores (
    id            SERIAL       PRIMARY KEY,
    razao_social  VARCHAR(150) NOT NULL,
    cnpj          VARCHAR(18)  NOT NULL UNIQUE,
    cidade        VARCHAR(100),
    estado        CHAR(2),
    email         VARCHAR(120),
    telefone      VARCHAR(20),
    ativo         BOOLEAN      NOT NULL DEFAULT TRUE,
    data_cadastro DATE         NOT NULL DEFAULT CURRENT_DATE,

    CONSTRAINT chk_fornecedores_estado CHECK (estado IS NULL OR LENGTH(TRIM(estado)) = 2)
);

COMMENT ON TABLE  fornecedores               IS 'Empresas fornecedoras dos produtos comercializados na plataforma';
COMMENT ON COLUMN fornecedores.id           IS 'Chave primária auto-incrementada';
COMMENT ON COLUMN fornecedores.razao_social IS 'Razão social completa da empresa fornecedora';
COMMENT ON COLUMN fornecedores.cnpj         IS 'CNPJ formatado: XX.XXX.XXX/XXXX-XX — único por fornecedor';
COMMENT ON COLUMN fornecedores.cidade       IS 'Cidade sede do fornecedor';
COMMENT ON COLUMN fornecedores.estado       IS 'Sigla do estado (UF) — 2 caracteres';
COMMENT ON COLUMN fornecedores.email        IS 'E-mail de contato comercial';
COMMENT ON COLUMN fornecedores.telefone     IS 'Telefone de contato';
COMMENT ON COLUMN fornecedores.ativo        IS 'TRUE = fornecedor ativo; FALSE = descredenciado';
COMMENT ON COLUMN fornecedores.data_cadastro IS 'Data de inclusão no sistema';

-- =============================================================================
-- TABELA: categorias
-- Hierarquia plana de categorias para classificação dos produtos.
-- Exemplos: Eletrônicos, Informática, Celulares, Roupas, etc.
-- =============================================================================
CREATE TABLE categorias (
    id        SERIAL       PRIMARY KEY,
    nome      VARCHAR(80)  NOT NULL UNIQUE,
    descricao TEXT
);

COMMENT ON TABLE  categorias           IS 'Categorias de classificação dos produtos do catálogo';
COMMENT ON COLUMN categorias.id       IS 'Chave primária auto-incrementada';
COMMENT ON COLUMN categorias.nome     IS 'Nome da categoria — único e exibido ao cliente';
COMMENT ON COLUMN categorias.descricao IS 'Descrição longa da categoria para uso interno e SEO';

-- =============================================================================
-- TABELA: produtos
-- Catálogo completo de produtos com preços, estoque e vínculos de categoria
-- e fornecedor. Tabela central do sistema de e-commerce.
-- =============================================================================
CREATE TABLE produtos (
    id              SERIAL        PRIMARY KEY,
    nome            VARCHAR(200)  NOT NULL,
    sku             VARCHAR(50)   NOT NULL UNIQUE,
    categoria_id    INTEGER       NOT NULL REFERENCES categorias(id),
    fornecedor_id   INTEGER       NOT NULL REFERENCES fornecedores(id),
    preco_custo     NUMERIC(12,2) NOT NULL,
    preco_venda     NUMERIC(12,2) NOT NULL,
    estoque_atual   INTEGER       NOT NULL DEFAULT 0,
    estoque_minimo  INTEGER       NOT NULL DEFAULT 5,
    ativo           BOOLEAN       NOT NULL DEFAULT TRUE,
    data_cadastro   DATE          NOT NULL DEFAULT CURRENT_DATE,

    CONSTRAINT chk_produtos_preco_custo    CHECK (preco_custo >= 0),
    CONSTRAINT chk_produtos_preco_venda    CHECK (preco_venda >= 0),
    CONSTRAINT chk_produtos_estoque_atual  CHECK (estoque_atual >= 0),
    CONSTRAINT chk_produtos_estoque_minimo CHECK (estoque_minimo >= 0)
);

COMMENT ON TABLE  produtos                 IS 'Catálogo de produtos disponíveis para venda no e-commerce';
COMMENT ON COLUMN produtos.id             IS 'Chave primária auto-incrementada';
COMMENT ON COLUMN produtos.nome           IS 'Nome descritivo do produto para exibição ao cliente';
COMMENT ON COLUMN produtos.sku            IS 'Stock Keeping Unit — código interno único de identificação';
COMMENT ON COLUMN produtos.categoria_id   IS 'FK para categorias.id — classificação do produto';
COMMENT ON COLUMN produtos.fornecedor_id  IS 'FK para fornecedores.id — quem abastece este produto';
COMMENT ON COLUMN produtos.preco_custo    IS 'Preço de compra do fornecedor (custo) em R$';
COMMENT ON COLUMN produtos.preco_venda    IS 'Preço de venda ao cliente final em R$';
COMMENT ON COLUMN produtos.estoque_atual  IS 'Saldo atual em estoque — atualizado por movimentacoes_estoque';
COMMENT ON COLUMN produtos.estoque_minimo IS 'Ponto de reorder: quando estoque_atual <= minimo, gera alerta';
COMMENT ON COLUMN produtos.ativo          IS 'TRUE = produto visível no catálogo; FALSE = descontinuado';
COMMENT ON COLUMN produtos.data_cadastro  IS 'Data de inclusão no catálogo';

-- =============================================================================
-- TABELA: clientes
-- Cadastro de compradores da plataforma.
-- =============================================================================
CREATE TABLE clientes (
    id            SERIAL       PRIMARY KEY,
    nome          VARCHAR(150) NOT NULL,
    email         VARCHAR(120) NOT NULL UNIQUE,
    cpf           VARCHAR(14)  UNIQUE,
    cidade        VARCHAR(100),
    estado        CHAR(2),
    data_cadastro DATE         NOT NULL DEFAULT CURRENT_DATE,
    ativo         BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_clientes_estado CHECK (estado IS NULL OR LENGTH(TRIM(estado)) = 2)
);

COMMENT ON TABLE  clientes               IS 'Cadastro de compradores registrados na plataforma de e-commerce';
COMMENT ON COLUMN clientes.id           IS 'Chave primária auto-incrementada';
COMMENT ON COLUMN clientes.nome         IS 'Nome completo do cliente';
COMMENT ON COLUMN clientes.email        IS 'E-mail único — usado para login e comunicação';
COMMENT ON COLUMN clientes.cpf          IS 'CPF formatado: XXX.XXX.XXX-XX — pode ser nulo (checkout sem cadastro)';
COMMENT ON COLUMN clientes.cidade       IS 'Cidade de entrega preferencial';
COMMENT ON COLUMN clientes.estado       IS 'Estado (UF) de entrega preferencial';
COMMENT ON COLUMN clientes.data_cadastro IS 'Data de criação da conta';
COMMENT ON COLUMN clientes.ativo        IS 'TRUE = conta ativa; FALSE = conta bloqueada ou excluída';

-- =============================================================================
-- TABELA: pedidos
-- Cabeçalho de cada transação de venda realizada na plataforma.
-- Relaciona cliente com os itens comprados e registra o status do pedido.
-- =============================================================================
CREATE TABLE pedidos (
    id              SERIAL        PRIMARY KEY,
    cliente_id      INTEGER       NOT NULL REFERENCES clientes(id),
    data_pedido     TIMESTAMP     NOT NULL DEFAULT NOW(),
    status          VARCHAR(30)   NOT NULL DEFAULT 'pendente',
    valor_total     NUMERIC(14,2),
    forma_pagamento VARCHAR(30),

    CONSTRAINT chk_pedidos_status CHECK (
        status IN ('pendente','confirmado','separando','enviado','entregue','cancelado')
    ),
    CONSTRAINT chk_pedidos_valor_total CHECK (valor_total IS NULL OR valor_total >= 0)
);

COMMENT ON TABLE  pedidos                  IS 'Cabeçalho de pedidos de venda — cada linha representa uma compra';
COMMENT ON COLUMN pedidos.id              IS 'Número do pedido — chave primária auto-incrementada';
COMMENT ON COLUMN pedidos.cliente_id      IS 'FK para clientes.id — comprador que realizou o pedido';
COMMENT ON COLUMN pedidos.data_pedido     IS 'Timestamp exato de criação do pedido — alvo de índice nos testes';
COMMENT ON COLUMN pedidos.status          IS 'Fluxo: pendente→confirmado→separando→enviado→entregue (ou cancelado)';
COMMENT ON COLUMN pedidos.valor_total     IS 'Soma dos (quantidade × preco_unitario × (1 - desconto)) dos itens';
COMMENT ON COLUMN pedidos.forma_pagamento IS 'Ex: cartao_credito, pix, boleto, cartao_debito';

-- =============================================================================
-- TABELA: itens_pedido
-- Linhas de produtos de cada pedido. Relação N:N entre pedidos e produtos.
-- =============================================================================
CREATE TABLE itens_pedido (
    id              SERIAL        PRIMARY KEY,
    pedido_id       INTEGER       NOT NULL REFERENCES pedidos(id),
    produto_id      INTEGER       NOT NULL REFERENCES produtos(id),
    quantidade      INTEGER       NOT NULL,
    preco_unitario  NUMERIC(12,2) NOT NULL,
    desconto        NUMERIC(5,2)  NOT NULL DEFAULT 0,

    CONSTRAINT chk_itens_quantidade  CHECK (quantidade > 0),
    CONSTRAINT chk_itens_desconto    CHECK (desconto >= 0 AND desconto <= 100),
    CONSTRAINT chk_itens_preco_unit  CHECK (preco_unitario >= 0)
);

COMMENT ON TABLE  itens_pedido                   IS 'Itens de cada pedido — linha de produtos comprados';
COMMENT ON COLUMN itens_pedido.id               IS 'Chave primária auto-incrementada';
COMMENT ON COLUMN itens_pedido.pedido_id        IS 'FK para pedidos.id — pedido ao qual este item pertence';
COMMENT ON COLUMN itens_pedido.produto_id       IS 'FK para produtos.id — produto comprado';
COMMENT ON COLUMN itens_pedido.quantidade       IS 'Quantidade de unidades compradas deste produto';
COMMENT ON COLUMN itens_pedido.preco_unitario   IS 'Preço do produto no momento da compra (snapshot imutável)';
COMMENT ON COLUMN itens_pedido.desconto         IS 'Percentual de desconto aplicado (0 a 100%)';

-- =============================================================================
-- TABELA: movimentacoes_estoque
-- Registro histórico de todas as entradas, saídas, ajustes e devoluções
-- de estoque. É a maior tabela do sistema em produção e o principal alvo
-- de otimização via particionamento e índices compostos.
-- =============================================================================
CREATE TABLE movimentacoes_estoque (
    id                  SERIAL      PRIMARY KEY,
    produto_id          INTEGER     NOT NULL REFERENCES produtos(id),
    tipo                VARCHAR(20) NOT NULL,
    quantidade          INTEGER     NOT NULL,
    data_movimentacao   TIMESTAMP   NOT NULL DEFAULT NOW(),
    pedido_id           INTEGER     REFERENCES pedidos(id),
    observacao          TEXT,

    CONSTRAINT chk_movimentacoes_tipo CHECK (
        tipo IN ('entrada','saida','ajuste','devolucao')
    )
);

COMMENT ON TABLE  movimentacoes_estoque                      IS 'Ledger de movimentações de estoque — cada linha é uma entrada, saída, ajuste ou devolução';
COMMENT ON COLUMN movimentacoes_estoque.id                  IS 'Chave primária auto-incrementada';
COMMENT ON COLUMN movimentacoes_estoque.produto_id          IS 'FK para produtos.id — produto movimentado';
COMMENT ON COLUMN movimentacoes_estoque.tipo                IS 'entrada=compra de fornecedor; saida=venda; ajuste=inventário; devolucao=cliente devolve';
COMMENT ON COLUMN movimentacoes_estoque.quantidade          IS 'Quantidade movimentada (sempre positiva; o tipo define a direção)';
COMMENT ON COLUMN movimentacoes_estoque.data_movimentacao   IS 'Timestamp da movimentação — alvo de índice composto e particionamento';
COMMENT ON COLUMN movimentacoes_estoque.pedido_id           IS 'FK para pedidos.id — preenchido quando tipo=saida ou tipo=devolucao';
COMMENT ON COLUMN movimentacoes_estoque.observacao          IS 'Notas livres: número NF, motivo do ajuste, fornecedor de entrada, etc.';

-- =============================================================================
-- VERIFICAÇÃO FINAL
-- =============================================================================
\echo ''
\echo '============================================================'
\echo 'Tabelas criadas com sucesso!'
\echo '============================================================'

\dt

SELECT
    relname AS "Tabela",
    pg_size_pretty(pg_total_relation_size(oid)) AS "Tamanho"
FROM pg_class
WHERE relkind = 'r' AND relnamespace = 'public'::REGNAMESPACE
ORDER BY relname;
