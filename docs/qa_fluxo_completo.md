# QA fluxo completo - Dono e Funcionario

## Objetivo
Validar a jornada principal do app em dois perfis: `dono/admin` e `funcionario/barbeiro`.

## Pre-condicoes
- App instalado e abrindo sem tela vazia.
- Base local SQLite inicializada.
- Pelo menos 1 usuario admin e 1 barbeiro validos.

## Fluxo 1 - Dono/Admin
1. Abrir app.
2. Fazer login como admin.
3. Validar redirecionamento para dashboard admin.
4. Abrir menu lateral e validar perfil `Dono/Admin`.
5. Navegar por:
   - Comandas
   - Atendimentos
   - Agenda
   - Clientes
   - Servicos
   - Produtos
   - Estoque
   - Financeiro
   - Caixa
   - Analytics
   - Ranking
   - Relatorios
6. Em Comandas:
   - Abrir nova comanda
   - Adicionar servico/produto
   - Fechar comanda
7. Voltar ao dashboard e validar atualizacao dos cards.
8. Fazer logout.

Resultado esperado:
- Todas as telas admin carregam sem erro.
- Navegacao volta para login apos logout.

## Fluxo 2 - Funcionario/Barbeiro
1. Abrir app.
2. Fazer login como barbeiro.
3. Validar redirecionamento para dashboard de barbeiro.
4. Abrir menu lateral e validar perfil `Funcionario`.
5. Validar acesso a:
   - Comandas
   - Atendimentos
   - Agenda
   - Clientes
6. Tentar acesso a rota admin (ex.: `/financeiro`).

Resultado esperado:
- Acesso admin bloqueado com tela `Acesso negado`.
- Botao de retorno leva ao dashboard do barbeiro.

## Regressao critica
- Inicializacao nao pode travar em splash.
- Rota inicial nao deve causar assert de `home` + `/`.
- Estado de auth deve sair de `verificando` com timeout de seguranca.
