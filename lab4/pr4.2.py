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

class OnlyCleanDiscountVisitor(OrderItemVisitor):
    def visit(self, item: ItemElement) -> float:
        cost = 0
        if isinstance(item, Clean):
            cost = item.get_price()
            cost -= cost * 0.15 
        elif isinstance(item, Oil):
            cost = item.get_capacity() * item.get_price()
        return cost

class OnlyOilDiscountVisitor(OrderItemVisitor):
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
        discount = OnlyCleanDiscountVisitor()
        cashier.set_discount(discount)
        print(f"Сумма заказа c учетом скидки на мойку: "
              f"{round(cashier.calculate_finish_price(),2)}")

    elif vibor=="Замена масла":
        discount = OnlyOilDiscountVisitor()
        cashier.set_discount(discount)
        print(f"Сумма заказа c учетом скидки на замену масла: "
              f"{round(cashier.calculate_finish_price(),2)}")

    print("Повторить? 1-Да")
    n = int(input())
print("Спасибо, что выбрали нашу компанию!")