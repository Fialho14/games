#include "scene.h"

#include <memory.h>

#include <array>
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <unordered_map>
#include <vector>

#include "common.h"
#include "display_symbol.h"
#include "i18n.h"
#include "utility.inl"
#include "color.h"

namespace {
constexpr int kAllDigitsMask = (1 << 9) - 1;

int boxIndex(int row, int column)
{
    return (row / 3) * 3 + column / 3;
}

int bitCount(int value)
{
    int count = 0;
    while (value != 0) {
        value &= value - 1;
        ++count;
    }
    return count;
}

int digitForBit(int bit)
{
    int digit = 1;
    while (bit > 1) {
        bit >>= 1;
        ++digit;
    }
    return digit;
}

void countSolutionsRecursive(std::array<int, 81>& board,
                             std::array<int, 9>& rowMasks,
                             std::array<int, 9>& columnMasks,
                             std::array<int, 9>& boxMasks,
                             const int limit,
                             int& solutions,
                             std::array<int, 81>* firstSolution)
{
    if (solutions >= limit)
        return;

    int bestIndex = -1;
    int bestCandidates = 0;
    int bestCandidateCount = 10;

    for (int index = 0; index < 81; ++index) {
        if (board[index] != 0)
            continue;

        const int row = index / 9;
        const int column = index % 9;
        const int candidates = kAllDigitsMask &
            ~(rowMasks[row] | columnMasks[column] | boxMasks[boxIndex(row, column)]);
        const int candidateCount = bitCount(candidates);
        if (candidateCount == 0)
            return;
        if (candidateCount < bestCandidateCount) {
            bestIndex = index;
            bestCandidates = candidates;
            bestCandidateCount = candidateCount;
            if (candidateCount == 1)
                break;
        }
    }

    if (bestIndex == -1) {
        if (solutions == 0 && firstSolution)
            *firstSolution = board;
        ++solutions;
        return;
    }

    const int row = bestIndex / 9;
    const int column = bestIndex % 9;
    const int box = boxIndex(row, column);
    while (bestCandidates != 0 && solutions < limit) {
        const int candidateBit = bestCandidates & -bestCandidates;
        bestCandidates &= ~candidateBit;
        const int value = digitForBit(candidateBit);

        board[bestIndex] = value;
        rowMasks[row] |= candidateBit;
        columnMasks[column] |= candidateBit;
        boxMasks[box] |= candidateBit;

        countSolutionsRecursive(board, rowMasks, columnMasks, boxMasks, limit,
                                solutions, firstSolution);

        board[bestIndex] = 0;
        rowMasks[row] &= ~candidateBit;
        columnMasks[column] &= ~candidateBit;
        boxMasks[box] &= ~candidateBit;
    }
}

int solutionCount(std::array<int, 81> board, const int limit,
                  std::array<int, 81>* firstSolution = nullptr)
{
    if (limit <= 0)
        return 0;

    std::array<int, 9> rowMasks{};
    std::array<int, 9> columnMasks{};
    std::array<int, 9> boxMasks{};
    for (int index = 0; index < 81; ++index) {
        const int value = board[index];
        if (value == 0)
            continue;
        if (value < 1 || value > 9)
            return 0;

        const int row = index / 9;
        const int column = index % 9;
        const int box = boxIndex(row, column);
        const int bit = 1 << (value - 1);
        if ((rowMasks[row] & bit) || (columnMasks[column] & bit) ||
            (boxMasks[box] & bit))
            return 0;
        rowMasks[row] |= bit;
        columnMasks[column] |= bit;
        boxMasks[box] |= bit;
    }

    int solutions = 0;
    countSolutionsRecursive(board, rowMasks, columnMasks, boxMasks, limit,
                            solutions, firstSolution);
    return solutions;
}
}  // namespace

CScene::CScene(int index)
    : _max_column(static_cast<int>(pow(index, 2)))
    , _cur_point({0, 0})
{
    init();
}

CScene::~CScene()
{
    if(keyMap) delete keyMap;
}

void CScene::show() const
{
    cls();

    printUnderline();

    // 获取光标位置的数字值（若光标在有效位置）
    int highlighted_num = UNSELECTED;
    if (_cur_point.y >= 0 && _cur_point.y < _max_column) {
        const CBlock& cursor_block = _row_block[_cur_point.y];
        highlighted_num = cursor_block.getNumberValue(_cur_point.x);
    }

    for (int row = 0; row < _max_column; ++row)
    {
        CBlock block = _row_block[row];
        if(_cur_point.y == row) block.print(_cur_point.x, highlighted_num);
        else block.print(-1, highlighted_num);
        printUnderline(row);
    }
}

void CScene::setMode(KeyMode mode)
{
    switch (mode)
    {
    case KeyMode::NORMAL:
        keyMap = new Normal;
        break;

    case KeyMode::VIM:
        keyMap = new Vim;
        break;
    }
}

void CScene::printUnderline(int line_no) const {
    auto is_curline = (_cur_point.y == line_no);
    for (int column = 0; column < 9; ++column) {
        if((column%3) == 0 || line_no == -1 || (line_no+1)%3 == 0) {
            std::cout << Color::Modifier(Color::BOLD, Color::BG_DEFAULT, Color::FG_RED) << CORNER << Color::Modifier();
        } else {
            std::cout <<  CORNER;
        }
        auto third_symbol = (is_curline && _cur_point.x == column) ? ARROW : LINE;
        if(line_no == -1 || (line_no+1)%3 == 0) {
            std::cout << Color::Modifier(Color::BOLD, Color::BG_DEFAULT, Color::FG_RED) << LINE << third_symbol << LINE << Color::Modifier();
        } else {
            std::cout << LINE << third_symbol << LINE;
        }
    }
    std::cout << Color::Modifier(Color::BOLD, Color::BG_DEFAULT, Color::FG_RED) << CORNER << Color::Modifier()<< std::endl;
}

void CScene::init()
{
    memset(_map, UNSELECTED, sizeof(_map));

    int col = 0;
    int row = 0;

    for(col = 0; col < _max_column; ++col)
    {
        CBlock column_block;

        for(row = 0; row < _max_column; ++row)
        {
            column_block.push_back(_map + row * _max_column + col);
        }

        _column_block[col] = column_block;
    }

    for(row = 0; row < _max_column; ++row)
    {
        CBlock row_block;

        for(col = 0; col < _max_column; ++col)
        {
            row_block.push_back(_map + row * _max_column + col);
        }

        _row_block[row] = row_block;
    }


    for(row = 0; row < _max_column; ++row)
    {
        for(col = 0; col < _max_column; ++col)
        {
            _xy_block[row / 3][col / 3].push_back(_map + row * _max_column + col);
        }
    }

    return;
}

bool CScene::setCurValue(const int nCurValue, int &nLastValue)
{
    auto point = _map[_cur_point.x + _cur_point.y * 9];
    if (point.state == State::ERASED)
    {
        nLastValue = point.value;
        setValue(nCurValue);
        return true;
    }
    else
        return false;
}

void CScene::setValue(const point_t& p, const int value)
{
    _map[p.x + p.y * 9].value = value;
}

void CScene::setValue(const int value)
{
    auto p = _cur_point;
    this->setValue(p, value);
}

// 选择count个格子清空
void CScene::eraseRandomGrids(const int count)
{
    point_value_t p = {UNSELECTED, State::ERASED};

    std::vector<int> v(81);
    for (int i = 0; i < 81; ++i) {
        v[i] = i;
    }

    for (int i = 0; i < count; ++i) {
        int r = random(0, static_cast<int>(v.size() - 1));
        _map[v[r]] = p;
        v.erase(v.begin() + r);
    }

    std::copy(std::begin(_map), std::end(_map), _initial.begin());
}

bool CScene::eraseUniqueGrids(const int count)
{
    std::vector<int> candidates(81);
    for (int index = 0; index < 81; ++index)
        candidates[index] = index;
    std::random_device randomDevice;
    std::mt19937 generator(randomDevice());
    std::shuffle(candidates.begin(), candidates.end(), generator);

    int erased = 0;
    for (const int index : candidates) {
        const point_value_t previous = _map[index];
        _map[index] = {UNSELECTED, State::ERASED};

        std::array<int, 81> puzzle{};
        for (int puzzleIndex = 0; puzzleIndex < 81; ++puzzleIndex)
            puzzle[puzzleIndex] = _map[puzzleIndex].value;

        if (solutionCount(puzzle, 2) == 1) {
            if (++erased == count) {
                std::copy(std::begin(_map), std::end(_map), _initial.begin());
                return true;
            }
        } else {
            _map[index] = previous;
        }
    }

    return false;
}

int CScene::countSolutions(const int limit) const
{
    std::array<int, 81> puzzle{};
    for (size_t index = 0; index < puzzle.size(); ++index)
        puzzle[index] = _initial[index].state == State::INITED
            ? _initial[index].value : UNSELECTED;
    return solutionCount(puzzle, limit);
}

bool CScene::isComplete()
{
    // 任何一个block未被填满，则肯定未完成
    for (size_t i = 0; i < 81; ++i)
    {
        if (_map[i].value == UNSELECTED)
            return false;
    }

    // 同时block里的数字还要符合规则
    for (int row = 0; row < 9; ++row)
    {
        for (int col = 0; col < 9; ++col)
        {
            if (!_row_block[row].isValid() || 
                !_column_block[col].isValid() || 
                !_xy_block[row / 3][col / 3].isValid())
                return false;
        }
    }

    return true;
}

int CScene::getPointValue(const point_t& point) const
{
    if (point.x < 0 || point.x >= 9 || point.y < 0 || point.y >= 9)
        return UNSELECTED;
    return _map[point.x + point.y * 9].value;
}

int CScene::getSolutionValue(const point_t& point) const
{
    if (point.x < 0 || point.x >= 9 || point.y < 0 || point.y >= 9)
        return UNSELECTED;
    return _solution[point.x + point.y * 9];
}

bool CScene::isGiven(const point_t& point) const
{
    if (point.x < 0 || point.x >= 9 || point.y < 0 || point.y >= 9)
        return false;
    return _map[point.x + point.y * 9].state == State::INITED;
}

bool CScene::applyValue(const point_t& point, const int value)
{
    if (value < 0 || value > 9 || point.x < 0 || point.x >= 9 ||
        point.y < 0 || point.y >= 9)
        return false;

    _cur_point = point;
    CCommand command(this);
    if (!command.execute(value))
        return false;

    _vCommand.push_back(command);
    return true;
}

bool CScene::undoLast()
{
    if (_vCommand.empty())
        return false;

    _vCommand.back().undo();
    _vCommand.pop_back();
    return true;
}

void CScene::restart()
{
    std::copy(_initial.begin(), _initial.end(), std::begin(_map));
    _vCommand.clear();
    _cur_point = {0, 0};
}

bool CScene::hasConflict(const point_t& point) const
{
    const int value = getPointValue(point);
    if (value == UNSELECTED)
        return false;

    for (int index = 0; index < 9; ++index) {
        if (index != point.x && _map[index + point.y * 9].value == value)
            return true;
        if (index != point.y && _map[point.x + index * 9].value == value)
            return true;
    }

    const int boxX = (point.x / 3) * 3;
    const int boxY = (point.y / 3) * 3;
    for (int y = boxY; y < boxY + 3; ++y) {
        for (int x = boxX; x < boxX + 3; ++x) {
            if ((x != point.x || y != point.y) &&
                _map[x + y * 9].value == value)
                return true;
        }
    }
    return false;
}

void CScene::loadGame(const std::array<int, 81>& values,
                      const std::array<bool, 81>& givens,
                      const std::array<int, 81>& solution)
{
    for (size_t index = 0; index < values.size(); ++index) {
        _map[index] = {values[index], givens[index] ? State::INITED : State::ERASED};
        _initial[index] = {givens[index] ? values[index] : 0,
                           givens[index] ? State::INITED : State::ERASED};
    }

    std::array<int, 81> puzzle{};
    for (size_t index = 0; index < puzzle.size(); ++index)
        puzzle[index] = _initial[index].value;
    std::array<int, 81> solved{};
    if (solutionCount(puzzle, 2, &solved) == 1)
        _solution = solved;
    else
        _solution = solution;

    _vCommand.clear();
    _cur_point = {0, 0};
}

bool CScene::save(const char *filename) {
  auto filepath = std::filesystem::path(filename);
  if (std::filesystem::exists(filepath)) {
    return false;
  }

    std::fstream fs;
    fs.open(filename, std::fstream::in | std::fstream::out | std::fstream::app);

    // save _map
    for (int i = 0; i < 81; i++) {
        fs << _map[i].value << ' ' << static_cast<int>(_map[i].state) << std::endl;
    }

    // save _cur_point
    fs << _cur_point.x << ' ' << _cur_point.y << std::endl;

    // save _vCommand
    fs << _vCommand.size() << std::endl;
    for (CCommand command : _vCommand) {
        point_t point = command.getPoint();
        fs << point.x << ' ' << point.y << ' '
           << command.getPreValue() << ' '
           << command.getCurValue() << std::endl;
    }

    fs.close();
    return true;
}

bool CScene::load(const char *filename) {
  auto filepath = std::filesystem::path(filename);
  if (!std::filesystem::exists(filepath)) {
    return false;
  }

    std::fstream fs;
    fs.open(filename, std::fstream::in | std::fstream::out | std::fstream::app);

    // load _map
    for (int i = 0; i < 81; i++) {
        int tmpState;
        fs >> _map[i].value >> tmpState;
        _map[i].state = static_cast<State>(tmpState);
    }

    // load _cur_point
    fs >> _cur_point.x >> _cur_point.y;

    // load _vCommand
    int commandSize;
    fs >> commandSize;
    for (int i = 0; i < commandSize; i++) {
        point_t point;
        int preValue, curValue;
        fs >> point.x >> point.y >> preValue >> curValue;
        _vCommand.emplace_back(this, point, preValue, curValue);
    }
    return true;
}

void CScene::play()
{
    show();

    char key = '\0';
    while (1)
    {
        key = static_cast<char>(_getch());
        if (key >= '0' && key <= '9')
        {
            CCommand oCommand(this);
            if (!oCommand.execute(key - '0'))
            {
                std::cout << "this number can't be modified." << std::endl;
            }
            else
            {
                _vCommand.push_back(std::move(oCommand));  // XXX: move without move constructor
                show();
                continue;
            }
        }
        if (key == keyMap->ESC)
        {
            message(I18n::Instance().Get(I18n::Key::ASK_QUIT));
            std::string strInput;
            std::cin >> strInput;
            if (strInput[0] == 'y' || strInput[0] == 'Y')
            {
                message(I18n::Instance().Get(I18n::Key::ASK_SAVE));
                std::cin >> strInput;
                if (strInput[0] == 'y' || strInput[0] == 'Y') {
                  do {
                    message(I18n::Instance().Get(I18n::Key::ASK_SAVE_PATH));
                    std::cin >> strInput;
                    if (!save(strInput.c_str())) {
                      message(I18n::Instance().Get(I18n::Key::FILE_EXIST_ERROR));
                    } else {
                      break;
                    }
                  } while (true);
                }
                exit(0);
            } else {
              message(I18n::Instance().Get(I18n::Key::CONTINUE));
            }
        }
        else if (key == keyMap->U)
        {
          if (_vCommand.empty()) {
            message(I18n::Instance().Get(I18n::Key::UNDO_ERROR));
          } else {
            CCommand &oCommand = _vCommand.back();
            oCommand.undo();
            _vCommand.pop_back();
            show();
          }
        }
        else if (key == keyMap->LEFT)
        {
            _cur_point.x = (_cur_point.x - 1) < 0 ? 0 : _cur_point.x - 1;
            show();
        }
        else if (key == keyMap->RIGHT)
        {
            _cur_point.x = (_cur_point.x + 1) > 8 ? 8 : _cur_point.x + 1;
            show();
        }
        else if (key == keyMap->DOWN)
        {
            _cur_point.y = (_cur_point.y + 1) > 8 ? 8 : _cur_point.y + 1;
            show();
        }
        else if (key == keyMap->UP)
        {
            _cur_point.y = (_cur_point.y - 1) < 0 ? 0 : _cur_point.y - 1;
            show();
        }
        else if (key == keyMap->ENTER)
        {
          if (isComplete()) {
            message(I18n::Instance().Get(I18n::Key::CONGRATULATION));
            getchar();
            exit(0);
          } else {
            message(I18n::Instance().Get(I18n::Key::NOT_COMPLETED));
          }
        }
    }
}

// 一个场景可以多次被初始化
void CScene::generate()
{
    _vCommand.clear();
    for (auto& point : _map)
        point = {UNSELECTED, State::INITED};

    std::vector<std::vector<int>> matrix;
    for (int i = 0; i < 9; i++)
        matrix.push_back(std::vector<int>(9, 0));

    // 初始化三个nuit
    // 2 6 5 | 0 0 0 | 0 0 0
    // 3 4 1 | 0 0 0 | 0 0 0
    // 8 9 7 | 0 0 0 | 0 0 0
    // ---------------------
    // 0 0 0 | 1 9 4 | 0 0 0
    // 0 0 0 | 8 3 6 | 0 0 0
    // 0 0 0 | 5 2 7 | 0 0 0
    // ---------------------
    // 0 0 0 | 0 0 0 | 3 4 5
    // 0 0 0 | 0 0 0 | 9 6 2
    // 0 0 0 | 0 0 0 | 7 8 1
    for (int num = 0; num < 3; num++)
    {
        std::vector<int> unit = shuffle_unit();
        int start_index = num * 3;
        for (int i = start_index; i < start_index+3; i++)
            for (int j = start_index; j < start_index+3; j++)
            {
                matrix[i][j] = unit.back();
                unit.pop_back();
            }
    }

    // 统计空格数量
    std::vector<std::tuple<int, int>> box_list;
    for (int i = 0; i < 9; i++)
        for (int j = 0; j < 9; j++)
            if (matrix[i][j] == 0)
                box_list.push_back(std::make_tuple(i, j));

    // 逐个填充空格
    std::map<std::string, std::vector<int>> available_num {};
    int full_num = 0;
    int empty_num = static_cast<int>(box_list.size());
    while (full_num < empty_num)
    {
        std::tuple<int, int> position = box_list[full_num];
        int row = std::get<0>(position);
        int col = std::get<1>(position);
        std::vector<int> able_unit;
        std::string key = std::to_string(row) + "x" + std::to_string(col);
        if (available_num.find(key) == available_num.end())
        {
            // 九宫格
            able_unit = get_unit();
            for(int i=row/3*3; i<row/3*3+3; i++){
                for(int j=col/3*3; j<col/3*3+3; j++){
                    able_unit.erase(std::remove(able_unit.begin(), able_unit.end(), matrix[i][j]), able_unit.end());
                }
            }
            // 行
            for (int i = 0; i < 9; i++)
                if (matrix[row][i] != 0)
                    able_unit.erase(std::remove(able_unit.begin(), able_unit.end(), matrix[row][i]), able_unit.end());
            // 列
            for (int i = 0; i < 9; i++)
                if (matrix[i][col] != 0)
                    able_unit.erase(std::remove(able_unit.begin(), able_unit.end(), matrix[i][col]), able_unit.end());
            available_num[key] = able_unit;
        }
        else
        {
            able_unit = available_num[key];
        }

        // 如果没有可用的数字，则回溯
        if (available_num[key].size() <= 0)
        {
            full_num -= 1;
            if (available_num.find(key) != available_num.end())
                available_num.erase(key);
            matrix[row][col] = 0;
            continue;
        }
        else
        {
            matrix[row][col] = available_num[key].back();
            available_num[key].pop_back();
            full_num += 1;
        }

    }

    // 填入场景
    for (int row = 0; row < 9; ++row)
    {
        for (int col = 0; col < 9; ++col)
        {
            point_t point = {row, col};
            setValue(point, matrix[row][col]);
        }
    }

    assert(isComplete());

    for (size_t index = 0; index < _solution.size(); ++index) {
        _solution[index] = _map[index].value;
        _initial[index] = _map[index];
    }

    return;
}

void CScene::newGame(Difficulty difficulty)
{
    int eraseCount = 35;
    switch (difficulty) {
    case Difficulty::EASY:
        eraseCount = 20;
        break;
    case Difficulty::NORMAL:
        eraseCount = 35;
        break;
    case Difficulty::HARD:
        eraseCount = 50;
        break;
    }

    do {
        generate();
    } while (!eraseUniqueGrids(eraseCount));

    assert(countSolutions(2) == 1);
}

bool CScene::setPointValue(const point_t &stPoint, const int nValue)
{
    auto point = _map[stPoint.x + stPoint.y * 9];
    if (State::ERASED == point.state)
    {
        _cur_point = stPoint;
        setValue(nValue);
        return true;
    }
    else
        return false;
}

point_t CScene::getCurPoint()
{
    return _cur_point;
}
