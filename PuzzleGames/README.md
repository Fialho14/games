# Puzzle Games para macOS

Uma app nativa e offline que reúne **Sudoku** e **Calcudoku** na mesma
experiência. O seletor junto ao título troca de jogo sem perder a partida: cada
jogo mantém separadamente o tabuleiro, notas, histórico, dificuldade e tempo.

## Abrir e jogar

A app pronta está instalada em
[`~/Applications/Puzzle Games.app`](~/Applications/Puzzle%20Games.app).
Pode ser aberta diretamente no Finder e movida para outra pasta. Não precisa de
terminal, CMake nem instalação de dependências. O projeto guarda também uma
cópia portátil verificada em
[`Artifacts/Puzzle Games.zip`](Artifacts/Puzzle%20Games.zip); ao descompactá-la
obtém exatamente a mesma `.app`.

Requisitos: macOS 14 ou posterior num Mac Apple Silicon. O bundle é assinado
localmente (assinatura ad hoc) e foi verificado depois de ser copiado para outro
diretório; não é uma distribuição notarizada para download público.

## Controlos

- Clique numa célula para a selecionar e use `1`–`9` (ou `1`–`N` no
  Calcudoku) para introduzir valores.
- Use as setas para navegar e `Delete`/`Backspace` para apagar.
- Use `N` ou **Notes** para ativar notas.
- Use `⌘Z` ou **Undo** para desfazer.
- Use `⌘N` ou **New Game** para gerar outro puzzle.
- **Restart** repõe o puzzle atual após confirmação.
- Clique no nome do jogo, no topo, para alternar entre Sudoku e Calcudoku.

O progresso é guardado automaticamente em `UserDefaults`. O Sudoku conserva a
chave histórica `sudoku.mac.saved-game.v1`, por isso uma partida da app anterior
é recuperada automaticamente. O Calcudoku usa `calcudoku.mac.saved-game.v1` e a
seleção do jogo usa `puzzle-games.selected-game.v1`.

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

Ambos os jogos têm seleção e conflitos visuais, notas, undo, apagar, restart,
timer, faixa numérica dinâmica e um estado de conclusão próprio.

## Estrutura

```text
Sources/
  PuzzleGames/
    App/                 composição e seleção de jogo
    Shared/              shell visual, tema, teclado e protocolo de sessão
    Games/Sudoku/        modelo e tabuleiro Sudoku
    Games/Calcudoku/     modelo e tabuleiro Calcudoku
  SudokuEngine/          motor C++ e ponte C
  CalcudokuEngine/       gerador/solver C e ponte C
Tests/
  PuzzleGamesTests/      testes XCTest e solvers de referência
  Native/                testes estritos dos dois motores
Assets/                  fonte PNG, iconset e AppIcon.icns
Scripts/                 build, testes e verificação do bundle
Legacy/                  interfaces de terminal preservadas para referência
macOS/                    Info.plist do bundle
```

Para adicionar outro jogo, crie um modelo que cumpra `PuzzleSession`, o respetivo
tabuleiro SwiftUI e, se necessário, um target de motor com uma API C pequena.
Depois registe-o em `GameKind`/`AppModel` e reutilize `PuzzleShellView`; assim o
novo jogo herda o mesmo layout, comandos e modal de conclusão sem acoplar o seu
estado aos restantes.

## Compilar, testar e verificar

É necessário Xcode/Swift 6 apenas para desenvolvimento:

```shell
swift test
./Scripts/test-native.sh
./Scripts/build-macos.sh
./Scripts/verify-macos.sh "/caminho/para/Puzzle Games.app"
```

O comando de build cria `Artifacts/Puzzle Games.app` e o arquivo de transporte
`Artifacts/Puzzle Games.zip`, remove metadados Finder incompatíveis, aplica a
assinatura ad hoc, valida `Info.plist`, assinatura e dependências, e repete a
validação numa cópia deslocada e numa extração limpa do ZIP. Em pastas Desktop
sincronizadas, prefira o ZIP para transporte: o File Provider pode acrescentar
metadados a uma `.app` visível depois de ela já ter sido assinada.

As suites dedicadas geram e validam:

- **180 Calcudokus distintos**: 90 no teste C e mais 90 com contagem de soluções
  cruzada por um solver Swift independente;
- **120 Sudokus**: 90 no teste C++ e mais 30 com solver Swift independente.

Além da unicidade, os testes cobrem regras de linhas/colunas, gaiolas contíguas,
operações e resultados, tamanhos/dificuldades, input, notas, undo, apagar,
restart, conclusão, autosave, isolamento entre jogos e atalhos reais de teclado
numa janela AppKit.

## Origem e licenças

O motor Sudoku e o projeto principal mantêm a licença GPLv3 em [`LICENSE`](LICENSE).
O gerador original do Calcudoku deriva do projeto `cdok`; o respetivo aviso ISC
foi preservado em
[`Sources/CalcudokuEngine/UPSTREAM-LICENSE.txt`](Sources/CalcudokuEngine/UPSTREAM-LICENSE.txt).
As interfaces CLI históricas não são necessárias em runtime e encontram-se em
[`Legacy/`](Legacy/).
