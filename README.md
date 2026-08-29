# Puzzle Games para macOS

Uma app nativa e offline que reúne **Sudoku**, **Calcudoku**, **Slitherlink**,
**Skyscrapers** e **Nurikabe** na mesma
experiência. O seletor junto ao título troca de jogo sem perder a partida: cada
jogo mantém separadamente o tabuleiro, ferramentas, histórico, dificuldade e tempo.

## Abrir e jogar

A app pronta fica em [`Artifacts/Puzzle Games.app`](Artifacts/Puzzle%20Games.app)
e cada build local atualiza automaticamente `~/Applications/Puzzle Games.app`,
que é a cópia encontrada pelo Spotlight. Não precisa de terminal, CMake nem
instalação de dependências. O projeto guarda também uma
cópia portátil verificada em
[`Artifacts/Puzzle Games.zip`](Artifacts/Puzzle%20Games.zip); ao descompactá-la
obtém exatamente a mesma `.app`.

Requisitos: macOS 14 ou posterior num Mac Apple Silicon. O bundle é assinado
localmente (assinatura ad hoc) e foi verificado depois de ser copiado para outro
diretório; não é uma distribuição notarizada para download público.

## Controlos

- Em Sudoku, Calcudoku e Skyscrapers, clique numa célula e use `1`–`N` para
  introduzir valores.
- Em Slitherlink, clique numa aresta para desenhar a linha ou um X; `1` e `2`
  aplicam essas marcas pelo teclado. As setas movem a aresta selecionada e
  `Shift` roda essa seleção 90° entre horizontal e vertical.
- Em Nurikabe, clique numa célula para marcar mar ou ilha; `1` e `2` aplicam
  essas marcas pelo teclado. As células numeradas são imutáveis.
- Use as setas para navegar e `Delete`/`Backspace` para apagar.
- Use `N` ou **Notes** para ativar notas nos jogos numéricos; nos restantes,
  `N` alterna entre as duas ferramentas próprias do jogo.
- Use `⌘Z` ou **Undo** para desfazer.
- Use `⌘N` ou **New Game** para gerar outro puzzle.
- **Restart** repõe o puzzle atual após confirmação.
- Clique no nome do jogo, no topo, para alternar entre os cinco jogos.

O progresso é guardado automaticamente em `UserDefaults`. O Sudoku conserva a
chave histórica `sudoku.mac.saved-game.v1`, por isso uma partida da app anterior
é recuperada automaticamente. Os restantes jogos usam chaves próprias
equivalentes e a seleção usa `puzzle-games.selected-game.v1`.

## Regras e dificuldades

No **Sudoku**, cada linha, coluna e bloco 3×3 contém os números 1–9 uma única
vez. Easy, Medium e Hard removem respetivamente 20, 35 e 50 células. Cada remoção
só é aceite se o puzzle continuar a ter exatamente uma solução.

No **Calcudoku**, cada linha e coluna contém 1–N uma única vez e cada gaiola tem
de satisfazer o resultado e a operação indicados. As dificuldades são 4×4,
5×5 e 6×6; níveis superiores usam tabuleiros maiores e uma fase de geração mais
longa. Subtração e divisão são usadas apenas em gaiolas de duas células, para
evitar interpretações ambíguas. A geração aceita somente puzzles com exatamente
uma solução, confirmada pelo solver exato.

No **Slitherlink**, as pistas 0–3 indicam quantas arestas da célula pertencem a
um único loop fechado, sem ramificações nem loops separados. Easy, Medium e Hard
usam grelhas 4×4, 5×5 e 6×6. O gerador constrói a fronteira de uma região válida,
deriva pistas e remove-as apenas enquanto o solver exato mantém uma solução.

Em **Skyscrapers**, cada linha/coluna é uma permutação de 1…N e as pistas
exteriores contam edifícios visíveis. As dificuldades usam 4×4, 5×5 e 6×6. O
solver cruza domínios de permutações; o gerador cria Latin Squares por
backtracking aleatório, rejeita bases ambíguas e testa unicidade após cada pista
removida.

No **Nurikabe**, cada ilha contém exatamente uma pista e o número correto de
células; todo o mar é conectado e nunca contém um bloco 2×2. As dificuldades são
5×5, 6×6 e 7×7. O gerador constrói primeiro um mar conectado acíclico, deriva as
ilhas e aceita apenas puzzles únicos. O solver inclui alcance/separação de ilhas,
conectividade do mar e prevenção de pools.

Os cinco jogos têm seleção, conflitos/check visual, undo, apagar, restart,
timer, autosave e conclusão próprios. Os jogos numéricos incluem notas;
Slitherlink e Nurikabe mostram apenas as ferramentas exigidas pelas regras. A
dificuldade dos jogos novos combina dimensão e trabalho medido pelo solver.

## Estrutura

```text
Sources/
  PuzzleGames/
    App/                 composição e seleção de jogo
    Shared/              shell visual, tema, teclado e protocolo de sessão
    Games/Sudoku/        modelo e tabuleiro Sudoku
    Games/Calcudoku/     modelo e tabuleiro Calcudoku
    Games/Slitherlink/   solver, gerador, modelo e tabuleiro de arestas
    Games/Skyscrapers/   solver, gerador, modelo e pistas exteriores
    Games/Nurikabe/      solver, gerador, modelo e tabuleiro mar/ilha
  SudokuEngine/          motor C++ e ponte C
  CalcudokuEngine/       gerador/solver C e ponte C
Tests/
  PuzzleGamesTests/
    Games/               testes espelhados por jogo
    Integration/         regressões entre sessões
  Native/                testes estritos dos dois motores
Assets/                  iconset fonte e AppIcon.icns
Scripts/                 build, testes e verificação do bundle
Documentation/           guia para adicionar jogos
Archive/Legacy/          interfaces de terminal históricas
Archive/Reference/       código externo opcional, fora do produto
macOS/                    Info.plist do bundle
```

Para adicionar outro jogo, siga o checklist em
[`Documentation/ADDING_A_GAME.md`](Documentation/ADDING_A_GAME.md). Em resumo:
crie engine/model/board e testes em pastas com o mesmo nome, registe o modelo em
`GameKind`/`AppModel`/`ContentView` e reutilize `PuzzleShellView`. Jogos numéricos
usam `.numbers`; jogos com duas ferramentas configuram `.twoState(...)` sem
introduzir condicionais específicas no shell ou um motor universal.

## Compilar, testar e verificar

É necessário Xcode/Swift 6 apenas para desenvolvimento:

```shell
swift test
./Scripts/test-native.sh
./Scripts/check-project.sh --bundle
./Scripts/build-macos.sh
./Scripts/install-macos.sh
./Scripts/verify-macos.sh "/caminho/para/Puzzle Games.app"
```

O comando de build cria `Artifacts/Puzzle Games.app` e o arquivo de transporte
`Artifacts/Puzzle Games.zip`, remove metadados Finder incompatíveis, aplica a
assinatura ad hoc, valida `Info.plist`, assinatura e dependências, e repete a
validação numa cópia deslocada e numa extração limpa do ZIP. Fora de CI, instala
também a mesma build em `~/Applications/Puzzle Games.app`; a versão anterior é
enviada para o Lixo e continua recuperável. Em pastas Desktop
sincronizadas, prefira o ZIP para transporte: o File Provider pode acrescentar
metadados a uma `.app` visível depois de ela já ter sido assinada.

As suites dedicadas geram e validam, entre outros casos:

- **180 Calcudokus distintos**: 90 no teste C e mais 90 com contagem de soluções
  cruzada por um solver Swift independente;
- **120 Sudokus**: 90 no teste C++ e mais 30 com solver Swift independente;
- **12 Slitherlinks** multi-seed nas três dificuldades, além de fixtures únicas,
  inválidas, ambíguas, múltiplos loops e ramificações;
- **9 Skyscrapers** multi-seed cruzados com um contador exato independente;
- **9 Nurikabes** multi-seed, mais regressões repetidas das seeds que expuseram
  dependência da ordem dos componentes durante o desenvolvimento.

Além da unicidade, os testes cobrem as regras globais específicas,
tamanhos/dificuldades, input, notas/ferramentas, undo, apagar, restart, conclusão,
autosave, isolamento ao alternar entre os cinco jogos e atalhos reais de teclado
numa janela AppKit. A pasta opcional `Archive/Reference/` não faz parte do
package, build, runtime nem testes.

## Origem e licenças

O motor Sudoku e o projeto principal mantêm a licença GPLv3 em [`LICENSE`](LICENSE).
O gerador original do Calcudoku deriva do projeto `cdok`; o respetivo aviso ISC
foi preservado em
[`Sources/CalcudokuEngine/UPSTREAM-LICENSE.txt`](Sources/CalcudokuEngine/UPSTREAM-LICENSE.txt).
As interfaces CLI históricas não são necessárias em runtime e encontram-se em
[`Archive/Legacy/`](Archive/Legacy/).
