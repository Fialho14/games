#ifndef _SUDOKU_SCENE_H_
#define _SUDOKU_SCENE_H_

#include <iostream>
#include <array>
#include <vector>
#include "common.h"
#include "block.h"
#include "command.h"

//数独场景类
class CScene
{
  public:
    CScene(int index = 3);
    virtual ~CScene();

    void generate();
    void newGame(Difficulty difficulty);
    void show() const;

    bool setCurValue(const int nCurValue, int& nLastValue);
    bool setPointValue(const point_t&, const int);
    point_t getCurPoint();

    void eraseRandomGrids(const int count);
    int countSolutions(int limit = 2) const;
    bool isComplete();
    bool hasConflict(const point_t&) const;

    int getPointValue(const point_t&) const;
    int getSolutionValue(const point_t&) const;
    bool isGiven(const point_t&) const;
    bool applyValue(const point_t&, const int);
    bool undoLast();
    void restart();
    void loadGame(const std::array<int, 81>& values,
                  const std::array<bool, 81>& givens,
                  const std::array<int, 81>& solution);

    void play();
    bool save(const char *filename);
    bool load(const char *filename);

    void setMode(KeyMode mode);

  private:
    void init(); // 将每个格子的指针放到block里面
    void setValue(const int);
    void setValue(const point_t &, const int);
    bool eraseUniqueGrids(const int count);
    void printUnderline(int line_no = -1) const;

private:
    KeyMap *keyMap{};
    int _max_column;
    point_t _cur_point;
    CBlock _column_block[9];
    CBlock _row_block[9];
    CBlock _xy_block[3][3];
    point_value_t _map[81];
    std::array<int, 81> _solution{};
    std::array<point_value_t, 81> _initial{};

    std::vector<CCommand> _vCommand;
};

#endif
