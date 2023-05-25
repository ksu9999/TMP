# coding=windows-1251
from abc import ABC, abstractmethod
from typing import List

class iterNum:
    def __init__(self, number):
        self.number = number

    def __str__(self):
        return f"{self.number}"

class Iterator(ABC):
    @abstractmethod
    def next(self) -> iterNum:
        ...

    @abstractmethod
    def has_next(self) -> bool:
        ...

class iterNumIterator(Iterator):
    def __init__(self, iter: List[iterNum]):
        self._iter = iter
        self._index = 0

    def next(self) -> iterNum:
        iter_item = self._iter[self._index]
        self._index += 1
        return iter_item

    def has_next(self) -> bool:
        return False if self._index >= len(self._iter) else True

class iterAggregate:
    def __init__(self, amount_num: int = 10):
        self.num = [iterNum(it+1) for it in range(amount_num)]
        print(f"Количество итераций "
              f"{amount_num}")

    def amount_num(self) -> int:
        return len(self.num)

    def iterator(self) -> Iterator:
        return iterNumIterator(self.num)

if __name__ == "__main__":
    iter = iterAggregate(10)
    iterator = iter.iterator()
    while iterator.has_next():
        item = iterator.next()
        print("Итерация №" + str(item))