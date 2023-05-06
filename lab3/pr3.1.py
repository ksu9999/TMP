
from abc import ABC, abstractmethod

class Oper(ABC):
    @abstractmethod
    def do_work(self, a, b):
        pass

class Adder(Oper):
    def do_work(self, a, b):
        return a + b

class Subtractor(Oper):
    def do_work(self, a, b):
        return a - b

class Multiplicator(Oper):
    def do_work(self, a, b):
        return a * b

class Calculator:
    def set_strategy(self, strategy: Oper):
        self.strategy = strategy
    def calculate(self, a, b):
        print('Результат', self.strategy.do_work(a, b))

calc = Calculator()

n=1
while n==1:
    print("Введите a")
    a = int(input())
    print("Введите b")
    b = int(input())
    print("Выберите операцию Сложение, Вычитание или Умножение")
    vvod=input()
    while vvod not in ("Сложение", "Вычитание", "Умножение"):
        print("Повторите ввод")
        vvod=input()
    if vvod == "Сложение":
        calc.set_strategy(Adder())
        calc.calculate(a, b)
    elif vvod == "Вычитание":
        calc.set_strategy(Subtractor())
        calc.calculate(a, b)
    elif vvod == "Умножение":
        calc.set_strategy(Multiplicator())
        calc.calculate(a, b)

    print("Повторить? (1-Да)")
    n=int(input())
print("Конец")