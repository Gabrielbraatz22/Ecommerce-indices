# Projeto de Pesquisa: Otimização (Tuning) de Consultas em PostgreSQL
## Estudo de Caso: E-commerce com Controle de Estoque

**Instituição:** [Nome da Instituição]
**Curso:** [Nome do Curso]
**Disciplina:** Banco de Dados / Sistemas de Gerenciamento de Banco de Dados
**Data:** 22 de maio de 2025

---

## 1.1 Introdução

O comércio eletrônico consolidou-se como um dos segmentos econômicos de maior crescimento global na última década. No Brasil, segundo dados da Associação Brasileira de Comércio Eletrônico (ABComm), o setor faturou mais de R$ 185 bilhões em 2023, com crescimento médio superior a 15% ao ano. Esse crescimento acelerado impõe desafios tecnológicos sem precedentes para as plataformas de venda online, especialmente no que diz respeito ao desempenho dos sistemas de gerenciamento de banco de dados que sustentam todas as operações transacionais.

**Tema:** Otimização (Tuning) de Banco de Dados em Sistemas de E-commerce com Controle de Estoque

**Delimitação do Problema:** Consultas em bancos de dados podem tornar-se progressivamente mais lentas caso sejam elaboradas inadequadamente ou recursos de otimização não sejam devidamente aplicados. Em sistemas de e-commerce com controle de estoque, esse problema assume caráter crítico, pois consultas de disponibilidade de produto, histórico de movimentações de estoque, relatórios de vendas e alertas de reposição são executadas com altíssima frequência e sobre volumes de dados que crescem continuamente. A ausência de índices estratégicos, a escrita ineficiente de consultas SQL e a configuração inadequada do SGBD resultam em tempos de resposta inaceitáveis, comprometendo a experiência do usuário final e a integridade operacional do negócio.

Este projeto delimita-se ao estudo empírico do impacto de técnicas de tuning no Sistema Gerenciador de Banco de Dados (SGBD) PostgreSQL, utilizando um modelo de dados representativo de um sistema de e-commerce com controle de estoque como ambiente de testes controlado.

---

## 1.2 Justificativa

### Relevância do E-commerce no Cenário Econômico Atual

O e-commerce brasileiro registrou um crescimento exponencial nos últimos anos, acelerado especialmente pelos efeitos da pandemia de COVID-19 e pela digitalização progressiva do consumo. Plataformas como Mercado Livre, Amazon Brasil, Shopee e milhares de lojas virtuais de médio e pequeno porte processam diariamente milhões de transações, cada uma das quais demandando múltiplas consultas ao banco de dados: verificação de estoque, registro de pedido, atualização de saldo de produto, geração de notas fiscais e atualização de dashboards gerenciais.

O volume de dados transacionais gerado por essas plataformas cresce em ritmo acelerado. Uma loja de médio porte com 10.000 produtos ativos e 5.000 pedidos diários gera, em um ano, mais de 1,8 milhão de pedidos, mais de 7 milhões de itens de pedido e potencialmente dezenas de milhões de movimentações de estoque. Escalar essa operação exige que o banco de dados responda com eficiência mesmo com volumes muito superiores.

### Impacto de Consultas Lentas em Plataformas de E-commerce

Pesquisas realizadas pelo Google e pela Akamai demonstram que cada segundo adicional de tempo de carregamento de uma página de e-commerce pode reduzir as taxas de conversão em até 7% e aumentar a taxa de abandono em até 11%. Em plataformas de alta demanda, onde as consultas ao banco de dados são o principal gargalo de tempo de resposta, a otimização do SGBD tem impacto direto e mensurável na receita da empresa.

Além do impacto na experiência do usuário, consultas lentas comprometem funções críticas do negócio:

- **Disponibilidade de produto em tempo real:** Se a consulta de verificação de estoque demora segundos, o cliente pode finalizar uma compra de um produto já esgotado, gerando cancelamentos, retrabalho operacional e insatisfação.
- **Relatórios gerenciais:** Gestores necessitam de relatórios de vendas, estoque crítico e ranking de produtos atualizados em tempo quase real para tomada de decisão. Consultas lentas inviabilizam esse fluxo.
- **Alertas de reposição:** A identificação de produtos com estoque abaixo do mínimo, executada frequentemente pelo sistema, deve ser instantânea para evitar ruptura de estoque, que representa perda direta de vendas.

### A Importância do Controle Eficiente de Estoque

O controle de estoque é uma das funções mais críticas de qualquer operação de e-commerce. Registros de entrada (compras de fornecedores), saída (vendas), ajustes (inventários) e devoluções precisam ser rastreados com precisão e agilidade. A tabela de movimentações de estoque tende a ser a de maior crescimento em volume — em operações de médio porte, pode acumular dezenas de milhões de registros em poucos anos. Sem otimização adequada, consultas de rastreamento de produto tornam-se praticamente inviáveis.

### Por que o PostgreSQL foi Escolhido

O PostgreSQL foi selecionado como sistema de gerenciamento de banco de dados para este estudo por um conjunto de razões técnicas e estratégicas:

1. **Robustez e confiabilidade:** Com mais de 35 anos de desenvolvimento ativo e uma comunidade global vibrante, o PostgreSQL oferece garantias de ACID compliance, recuperação após falhas e suporte a operações concorrentes que o tornam adequado para ambientes transacionais de alta carga.

2. **Recursos avançados de indexação:** O PostgreSQL suporta múltiplos tipos de índices (B-tree, Hash, GIN, GiST, BRIN, SP-GiST), índices parciais, índices compostos, índices funcionais e a cláusula INCLUDE para índices de cobertura. Essa riqueza permite otimizações finas que impactam diretamente o desempenho em e-commerce.

3. **Suporte a JSONB:** Para catálogos de produtos com atributos variáveis por categoria (eletrônicos têm voltagem e garantia; roupas têm tamanho e material), o tipo JSONB com indexação GIN permite armazenar e consultar atributos semi-estruturados com eficiência.

4. **Extensões como pg_stat_statements:** A extensão pg_stat_statements permite monitorar as queries mais lentas em ambiente de produção, fornecendo dados precisos para decisões de otimização baseadas em evidências.

5. **Código aberto e amplamente adotado:** Por ser licenciado sob a PostgreSQL License (semelhante à MIT), é acessível em qualquer ambiente educacional e corporativo, e está entre os SGBDs mais utilizados no mundo segundo o ranking DB-Engines.

6. **Particionamento declarativo:** O PostgreSQL suporta nativamente o particionamento por range, list e hash desde a versão 10, sendo ideal para tabelas de movimentações de estoque e pedidos que crescem continuamente ao longo do tempo.

### Necessidade de Profissionais com Domínio de Tuning

O mercado de tecnologia demanda crescentemente profissionais capazes de identificar gargalos de performance em sistemas de banco de dados e aplicar soluções eficazes. Desenvolvedores back-end, arquitetos de dados e administradores de banco de dados que dominam ferramentas como EXPLAIN ANALYZE, conhecem os tipos de índices disponíveis e sabem configurar adequadamente os parâmetros de memória do SGBD são capazes de entregar sistemas mais eficientes com menor custo de infraestrutura.

---

## 1.3 Objetivos

### Objetivo Geral

Investigar e demonstrar empiricamente o impacto de técnicas de otimização de consultas no desempenho do PostgreSQL, aplicadas a um sistema de e-commerce com controle de estoque, comparando tempos de execução em diferentes volumes de dados e configurações de índices, com o intuito de produzir evidências quantitativas que fundamentem boas práticas de tuning para ambientes de e-commerce.

### Objetivos Específicos

1. **Modelar** um banco de dados relacional representativo de um sistema de e-commerce com controle de estoque, composto por seis tabelas inter-relacionadas: fornecedores, categorias, produtos, clientes, pedidos, itens_pedido e movimentacoes_estoque.

2. **Implementar** um procedimento automatizado (stored procedure) para geração de dados sintéticos em diferentes volumes (10.000, 20.000, 30.000 e 1.000.000 pedidos), garantindo integridade referencial e realismo nos dados gerados.

3. **Medir e comparar** os tempos de execução de seis consultas representativas do domínio de e-commerce, com e sem índices, utilizando EXPLAIN ANALYZE e a diretiva `\timing` do cliente psql.

4. **Analisar** o comportamento de desempenho das consultas à medida que o volume de dados cresce, identificando padrões de degradação sem índice e o comportamento mais suave (logarítmico) com índices.

5. **Pesquisar e descrever** outros métodos de otimização disponíveis no PostgreSQL além dos índices simples: particionamento, Materialized Views, índices parciais, índices de cobertura (INCLUDE), pg_stat_statements e configurações de memória.

6. **Elaborar conclusões** baseadas em evidências empíricas coletadas durante os testes, propondo recomendações práticas para equipes de desenvolvimento e operações que trabalham com sistemas de e-commerce em PostgreSQL.

---

## 1.4 Fundamentação Teórica

### 1.4.1 Tuning de Banco de Dados em Sistemas Transacionais de Alto Volume

O tuning de banco de dados é o processo sistemático de análise e eliminação de gargalos de desempenho em sistemas de gerenciamento de banco de dados, com o objetivo de reduzir o tempo de resposta das operações e maximizar o uso eficiente dos recursos computacionais. Em sistemas transacionais de alto volume — como plataformas de e-commerce —, o tuning deixa de ser um diferencial e passa a ser uma necessidade operacional.

Sistemas OLTP (Online Transaction Processing), que caracterizam o e-commerce, são marcados por um grande número de transações curtas e frequentes: inserções de pedidos, atualizações de estoque, consultas de produto e relatórios gerenciais executados concorrentemente por centenas ou milhares de usuários simultâneos. Cada milissegundo de diferença no tempo de resposta de uma query, multiplicado pelo número de execuções diárias, resulta em impacto acumulado significativo no desempenho geral do sistema.

O ciclo de tuning envolve: (1) identificação de queries lentas via ferramentas de monitoramento (pg_stat_statements), (2) análise do plano de execução (EXPLAIN ANALYZE), (3) identificação de oportunidades — índices ausentes, estatísticas desatualizadas, queries mal escritas —, (4) aplicação das otimizações e (5) medição do impacto. Esse ciclo deve ser repetido continuamente, especialmente após alterações significativas no volume de dados.

### 1.4.2 Plano de Execução: EXPLAIN e EXPLAIN ANALYZE

O plano de execução é a estratégia que o otimizador de consultas do PostgreSQL seleciona para responder a uma instrução SQL. O otimizador — baseado em custos — avalia múltiplas estratégias possíveis e escolhe aquela com menor custo estimado, utilizando as estatísticas de distribuição de dados armazenadas nos catálogos do sistema.

O comando `EXPLAIN` exibe o plano estimado sem executar a query. `EXPLAIN ANALYZE` executa a query e exibe tanto o plano estimado quanto as métricas reais de execução. As informações mais relevantes incluem:

- **cost (start..total):** Custo estimado em unidades arbitrárias. O custo de inicialização representa o custo antes de retornar a primeira linha; o custo total é o custo estimado para retornar todas as linhas.
- **rows:** Número estimado de linhas retornadas pelo nó.
- **actual time:** Tempo real de execução em milissegundos (start..end), disponível apenas com ANALYZE.
- **loops:** Número de vezes que o nó foi executado.
- **Buffers:** Com o parâmetro BUFFERS, exibe quantas páginas foram lidas do cache (shared hit) e do disco (read).

A interpretação correta do plano é a habilidade central do tuning. Nós com "Seq Scan" em tabelas grandes, "Rows Removed by Filter" elevado, e discrepâncias entre rows estimados e reais são sinais de problemas de otimização.

### 1.4.3 Índices no PostgreSQL: Tipos e Aplicações em E-commerce

**B-tree:** É o tipo padrão, armazenando dados ordenados em uma estrutura de árvore balanceada. Suporta operações de igualdade, comparação e intervalos. É o tipo mais adequado para a maioria das colunas de filtro em sistemas de e-commerce: `status`, `data_pedido`, `categoria_id`, `cliente_id`. O custo de acesso é O(log N), tornando-o eficiente mesmo para tabelas com milhões de registros.

**Hash:** Otimizado exclusivamente para igualdade. Pode ser mais rápido que B-tree em buscas por igualdade exata, mas não suporta `<`, `>`, `BETWEEN` ou `ORDER BY`. Adequado para lookup por SKU ou CPF quando apenas igualdade é necessária.

**GIN (Generalized Inverted Index):** Ideal para tipos compostos: arrays, JSONB e busca de texto completo. Em e-commerce com atributos variáveis por produto (armazenados em JSONB), o GIN permite consultas eficientes como `WHERE atributos @> '{"cor": "azul"}'`.

**GiST:** Framework extensível que suporta dados geoespaciais (PostGIS), intervalos e busca por proximidade. Em e-commerce com funcionalidade de loja mais próxima ou entrega por CEP, o GiST é fundamental.

**BRIN (Block Range Index):** Extremamente compacto, armazena apenas o valor mínimo e máximo de cada bloco físico de dados. Ideal para tabelas de movimentações de estoque e pedidos onde os dados têm correlação temporal com a ordem de inserção (INSERT sequencial por data). Para a tabela `movimentacoes_estoque`, um BRIN na coluna `data_movimentacao` pode ser mais eficiente que um B-tree quando a tabela tem dezenas de milhões de registros e as consultas filtram por períodos grandes.

### 1.4.4 Estratégias de Acesso: Sequential Scan vs Index Scan vs Bitmap Index Scan

**Sequential Scan:** Lê todas as páginas da tabela sequencialmente. Eficiente para consultas que retornam grande proporção das linhas (>5-10%). Em tabelas pequenas, frequentemente mais rápido que o uso de índices. Para a tabela de movimentações de estoque com milhões de registros, um Sequential Scan sem filtro eficaz é catastrófico.

**Index Scan:** Percorre o índice para localizar ponteiros para as páginas de dados, depois acessa as heap pages individualmente. Eficiente para consultas com alta seletividade (poucas linhas retornadas). O acesso aleatório às heap pages pode ser lento em discos HDD, mas é eficiente em SSDs.

**Bitmap Index Scan:** O PostgreSQL cria um mapa de bits de todas as páginas que contêm linhas relevantes, depois acessa essas páginas em ordem física. É uma estratégia intermediária: mais eficiente que o Index Scan quando muitas linhas são retornadas (pois reduz acessos aleatórios), mas menos eficiente que o Sequential Scan para retornos muito grandes.

**Index-Only Scan:** Ocorre quando todas as colunas necessárias estão no índice (seja nas colunas indexadas ou via cláusula INCLUDE). Elimina completamente o acesso às heap pages, sendo o método mais eficiente quando aplicável.

### 1.4.5 Estatísticas, VACUUM e ANALYZE

O otimizador do PostgreSQL baseia suas estimativas de custo nas estatísticas de distribuição de dados coletadas pelo `ANALYZE`. Quando as estatísticas estão desatualizadas, o otimizador pode escolher planos subótimos — por exemplo, estimar que uma consulta retorna 10 linhas quando retorna 10.000, levando à escolha incorreta de Index Scan quando Sequential Scan seria mais eficiente.

O `VACUUM` remove dead tuples geradas pelo mecanismo MVCC após UPDATEs e DELETEs. Em sistemas de e-commerce com alta taxa de atualização de estoque, o acúmulo de dead tuples pode degradar significativamente o desempenho das consultas (mais páginas para ler) e aumentar o tamanho das tabelas.

O `autovacuum` do PostgreSQL executa VACUUM e ANALYZE automaticamente em background, mas pode não ser suficiente em tabelas de alta atividade. O monitoramento de `n_dead_tup` e `last_autovacuum` via `pg_stat_user_tables` é recomendado.

### 1.4.6 Particionamento de Tabelas em E-commerce

Para tabelas que crescem continuamente como `movimentacoes_estoque` e `pedidos`, o particionamento por range temporal é uma das estratégias mais eficazes de longo prazo. Ao dividir os dados por mês ou ano, o PostgreSQL realiza *partition pruning*: consultas com filtro temporal leem apenas as partições relevantes, ignorando completamente as demais. Uma consulta de movimentações do mês de março, por exemplo, lê apenas a partição de março, mesmo que a tabela total contenha anos de histórico.

Além do ganho em consultas, o particionamento facilita a manutenção: VACUUM, REINDEX e arquivamento de dados históricos podem ser realizados partição a partição, sem impactar a tabela ativa.

### 1.4.7 Configurações de Memória

**shared_buffers:** Cache compartilhado de páginas de dados. Recomenda-se 25% a 40% da RAM disponível. Em um servidor dedicado com 8GB de RAM, configurar `shared_buffers = 2GB` mantém as páginas mais acessadas (catálogo de produtos, pedidos recentes) em memória, evitando leitura de disco.

**work_mem:** Memória alocada por operação de ordenação ou hash. Consultas de ranking de produtos (ORDER BY com GROUP BY) e relatórios de vendas se beneficiam de values maiores. Com `work_mem = 64MB`, operações de sort para relatórios de e-commerce com dezenas de milhares de linhas ocorrem inteiramente em memória, sem arquivos temporários em disco.

**effective_cache_size:** Estimativa do cache disponível (PostgreSQL + sistema operacional). Influi diretamente na escolha entre Index Scan e Sequential Scan pelo otimizador. Em servidores com 8GB de RAM, configurar `effective_cache_size = 6GB` informa ao otimizador que há bastante cache disponível, favorecendo a escolha de Index Scans.

### 1.4.8 Boas Práticas de Escrita de Queries em Sistemas Transacionais

**Evitar SELECT \*:** Em tabelas com muitas colunas (como produtos, com atributos em JSONB), selecionar apenas as colunas necessárias reduz a quantidade de dados transferidos e abre possibilidade de Index-Only Scans.

**Filtros em colunas indexadas:** Aplicar funções em colunas indexadas impede o uso do índice. `WHERE DATE(data_pedido) = '2024-01-01'` impede o uso do índice em `data_pedido`. A forma correta é `WHERE data_pedido >= '2024-01-01' AND data_pedido < '2024-01-02'`.

**CTEs no PostgreSQL 12+:** A partir da versão 12, CTEs não recursivas são automaticamente inlineadas pelo otimizador (equivalentes a subqueries), eliminando a barreira de materialização obrigatória das versões anteriores. Use `WITH ... AS MATERIALIZED` para forçar a materialização quando necessário.

**Paginação eficiente:** Em catálogos de produtos com filtros e ordenação, o `OFFSET` cresce em custo de forma linear. A técnica de *keyset pagination* (buscar pela última chave retornada) é O(log N) e muito mais eficiente para paginar grandes catálogos.

---

## 1.5 Metodologia

### Modelo de Dados

O modelo de dados adotado neste projeto representa um sistema de e-commerce com controle de estoque, composto por sete tabelas inter-relacionadas:

- **fornecedores:** Dados cadastrais dos fornecedores dos produtos
- **categorias:** Hierarquia de categorias dos produtos
- **produtos:** Catálogo com preços, estoque e vínculos com fornecedor e categoria
- **clientes:** Cadastro de compradores com dados de contato e localização
- **pedidos:** Cabeçalho das transações de venda
- **itens_pedido:** Linhas de cada pedido com produto, quantidade e preço
- **movimentacoes_estoque:** Registro completo de entradas, saídas, ajustes e devoluções

### Volumes de Dados Testados

| Cenário | Pedidos | Itens Pedido | Movimentações |
|---------|---------|--------------|---------------|
| Base    | 10.000  | ~35.000      | ~60.000       |
| 2×      | 20.000  | ~70.000      | ~120.000      |
| 3×      | 30.000  | ~105.000     | ~180.000      |
| Produção| 1.000.000 | ~3.500.000 | ~6.000.000   |

### Consultas Selecionadas

As seis consultas foram escolhidas por representarem operações críticas e frequentes em sistemas de e-commerce:

1. **Busca por categoria e disponibilidade:** Consulta do catálogo pelo cliente
2. **Relatório de vendas por período:** Consulta gerencial recorrente
3. **Estoque abaixo do mínimo:** Alerta operacional de reposição
4. **Histórico de movimentações:** Rastreabilidade de produto
5. **Ranking de produtos vendidos:** Relatório de desempenho
6. **Clientes VIP (CTE):** Identificação para programa de fidelidade

### Protocolo de Medição

1. Habilitação de `\timing on` no psql para captura do tempo cliente
2. Execução de `EXPLAIN (ANALYZE, BUFFERS)` para captura do plano real
3. Registro do campo "Execution Time" do EXPLAIN ANALYZE (tempo interno, sem overhead de rede)
4. Cada consulta executada três vezes; registro da média das duas últimas (descartando cold cache)
5. Entre volumes: TRUNCATE + CALL popular_dados(N) + ANALYZE em todas as tabelas

---

## 1.6 Conclusões

> **[PLACEHOLDER — A ser preenchido após análise dos resultados dos testes]**
>
> Esta seção deve ser completada após a execução de todos os scripts SQL e coleta dos tempos na planilha `resultados/tempos_execucao.xlsx`. As conclusões devem responder:
>
> 1. **Os índices reduziram significativamente os tempos?** Quantificar a redução média percentual para cada consulta e cada volume.
>
> 2. **O ganho foi proporcional ao crescimento do volume?** Analisar se a redução percentual se manteve ou aumentou conforme o volume cresceu de 10k para 1M.
>
> 3. **Quais consultas se beneficiaram mais?** Identificar as consultas com maior speedup e relacionar com o tipo de índice utilizado e a seletividade da consulta.
>
> 4. **Quais técnicas complementares foram mais relevantes?** Avaliar o impacto do particionamento de movimentacoes_estoque, das Materialized Views para o ranking de produtos e dos índices parciais para pedidos ativos.
>
> 5. **Quais são as limitações do estudo?** Dados sintéticos vs. dados reais de produção, ausência de concorrência simulada, hardware de teste vs. servidor de produção.
>
> 6. **Recomendações para sistemas de e-commerce em produção:** Quais práticas deveriam ser adotadas desde o início do projeto? Quais são as otimizações de maior impacto com menor risco?

---

## 1.7 Referências

1. POSTGRESQL GLOBAL DEVELOPMENT GROUP. **PostgreSQL 16 Documentation**. Disponível em: https://www.postgresql.org/docs/16/. Acesso em: mai. 2025.

2. WINAND, Markus. **Use The Index, Luke — A Guide to Database Performance for Developers**. Disponível em: https://use-the-index-luke.com/. Acesso em: mai. 2025.

3. OBE, Regina O.; HSU, Leo S. **PostgreSQL: Up and Running**. 3. ed. O'Reilly Media, 2017. ISBN: 978-1491963418.

4. CHRISTOPH, Pettus. **PostgreSQL 9.0 High Performance**. Packt Publishing, 2010. ISBN: 978-1849510301.

5. ELMASRI, Ramez; NAVATHE, Shamkant B. **Sistemas de Banco de Dados**. 7. ed. Pearson, 2019. ISBN: 978-8543020297.

6. PGANALYZE. **Postgres Index Types and When to Use Them**. Disponível em: https://pganalyze.com/blog/postgres-index-types. Acesso em: mai. 2025.

7. POSTGRESQL GLOBAL DEVELOPMENT GROUP. **pg_stat_statements — Track Statistics of SQL Planning and Execution**. Disponível em: https://www.postgresql.org/docs/current/pgstatstatements.html. Acesso em: mai. 2025.

8. PGMUSTARD. **Understanding Postgres Query Plans**. Disponível em: https://www.pgmustard.com/. Acesso em: mai. 2025.

9. DATE, C. J. **Introdução a Sistemas de Bancos de Dados**. 8. ed. Elsevier, 2004. ISBN: 978-8535212730.

10. ASSOCIAÇÃO BRASILEIRA DE COMÉRCIO ELETRÔNICO (ABComm). **Relatório Anual do E-commerce Brasileiro 2023**. São Paulo: ABComm, 2024.
