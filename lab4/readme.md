# Практическая работа №4. Итератор, посетитель
### Код программы для диаграммы паттерна Итератор
```
@startuml
title Пратическая работа 4: Iterator

class iterNum{
init()
str()
}

class  Iterator{
next(self)
has_next(self)
}

class iterNumIterator{
init()
next(self)
has_next(self)
}

class iterAggregate{
init()
amount_num()
iterator()
}

class main{
iter = iterAggregate(5)
iterator = iter.iterator()
}

main -> iterAggregate
main ..>Iterator:<<create>>
iterNumIterator <.. iterAggregate: <<create>>
iterNumIterator o-- iterAggregate
iterNumIterator --> Iterator
iterNum <-up- Iterator
iterNum <- iterAggregate

@enduml
```
### Диаграмма паттерна Итератор
![alt text](https://github.com/ksu9999/TMP/blob/master/lab4/pr4.1.png)
### Код программы для реализации паттерна Итератор
```
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
```
### Результат реализации паттерна Итератор
![alt text](https://github.com/ksu9999/TMP/blob/master/lab4/rr4.1.png)
### Код программы для диаграммы паттерна Посетитель
```
@startuml
title Пратическая работа 4: Visitor

class OrderItemVisitor{
<<interface>>
visit(self, item)
}

class ItemElement{
<<interface>>
accept(self, visitor: OrderItemVisitor)
}

class Clean{
init()
get_price(self)
accept(self, visitor: OrderItemVisitor)
}

class  Oil{
init()
get_price(self)
accept(self, visitor: OrderItemVisitor)
}

class WithOutDiscountVisitor{
visit(self, item: ItemElement)
}

class CleanDiscountVisitor{
visit(self, item: ItemElement)
}

class OilDiscountVisitor{
visit(self, item: ItemElement)
}

WithOutDiscountVisitor..>OrderItemVisitor
CleanDiscountVisitor..>OrderItemVisitor
OilDiscountVisitor..>OrderItemVisitor

OrderItemVisitor..>Clean
OrderItemVisitor..>Oil

ItemElement..left..>OrderItemVisitor
Clean..>ItemElement
Oil ..>ItemElement
@enduml
```
### Диаграмма паттерна Посетитель
![alt text](https://github.com/ksu9999/TMP/blob/master/lab4/pr4.2.png)
### Код программы для реализации паттерна Посетитель
```
# coding=windows-1251
from abc import ABC, abstractmethod
from typing import List

class OrderItemVisitor(ABC):
    @abstractmethod
    def visit(self, item) -> float:
        ...

class ItemElement(ABC):
    @abstractmethod
    def accept(self, visitor: OrderItemVisitor) -> float:
        ...

class Clean(ItemElement):
    def __init__(self, name: str, price: float):
        self.name = name
        self.price = price

    def get_price(self) -> float:
        return self.price

    def accept(self, visitor: OrderItemVisitor) -> float:
        return visitor.visit(self)

class Oil(ItemElement):
    def __init__(self, name: str,
                 price: float,
                 capacity: float):
        self.name = name
        self.price = price
        self.capacity = capacity

    def get_price(self) -> float:
        return self.price

    def get_capacity(self) -> float:
        return self.capacity

    def accept(self, visitor: OrderItemVisitor) -> float:
        return visitor.visit(self)

class WithOutDiscountVisitor(OrderItemVisitor):
    def visit(self, item: ItemElement) -> float:
        cost = 0
        if isinstance(item, Clean):
            cost = item.get_price()
        elif isinstance(item, Oil):
            cost = item.get_capacity() * item.get_price()
        return cost

class  CleanDiscountVisitor(OrderItemVisitor):
    def visit(self, item: ItemElement) -> float:
        cost = 0
        if isinstance(item, Clean):
            cost = item.get_price()
            cost -= cost * 0.15 
        elif isinstance(item, Oil):
            cost = item.get_capacity() * item.get_price()
        return cost

class  OilDiscountVisitor(OrderItemVisitor):
    def visit(self, item: ItemElement) -> float:
        cost = 0
        if isinstance(item, Clean):
            cost = item.get_price()
        elif isinstance(item, Oil):
            cost = item.get_capacity() * item.get_price()
            cost -= cost * 0.2
        return cost

class Cashier:
    def __init__(self, discount: OrderItemVisitor):
        self.order: List[ItemElement] = []
        self.discount_calculator = discount

    def set_order(self, order: List[ItemElement]) -> None:
        self.order = order

    def set_discount(self, discount: OrderItemVisitor) -> None:
        self.discount_calculator = discount

    def calculate_finish_price(self) -> float:
        price = 10000
        if self.order:
            for item in self.order:
                price += item.accept(self.discount_calculator)
        return price

order: List[ItemElement] = [Clean("Комплекс", 600),
                            Oil("МКПП", 100, 0.8),
                            Clean("Обычная", 300),
                            Oil("ФКПП", 100, 1.5)]
discount = WithOutDiscountVisitor()
cashier = Cashier(discount)
cashier.set_order(order)

n=1
while n==1:
    print("Введите скидку на дополнительную услугу : Без, Мойка, Замена масла")
    vibor=input()
    while vibor not in ("Без", "Мойка", "Замена масла"):
        print("Повторите ввод")
        vibor=input()

    if vibor=="Без":
        discount = WithOutDiscountVisitor()
        cashier = Cashier(discount)
        cashier.set_order(order)
        print(f"Сумма заказа без учета скидок: "
              f"{round(cashier.calculate_finish_price(),2)}")

    elif vibor=="Мойка":
        discount =  CleanDiscountVisitor()
        cashier.set_discount(discount)
        print(f"Сумма заказа c учетом скидки на мойку: "
              f"{round(cashier.calculate_finish_price(),2)}")

    elif vibor=="Замена масла":
        discount =  OilDiscountVisitor()
        cashier.set_discount(discount)
        print(f"Сумма заказа c учетом скидки на замену масла: "
              f"{round(cashier.calculate_finish_price(),2)}")

    print("Повторить? 1-Да")
    n = int(input())
print("Спасибо, что выбрали нашу компанию!")
```
### Результат реализации паттерна Посетитель
![alt text](https://github.com/ksu9999/TMP/blob/master/lab4/rr4.2.png)