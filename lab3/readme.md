# Практическая работа №3. Шаблонный метод, Стратегия
### Код программы для диаграммы паттерна Стратегия
```
@startuml
title Пратическая работа 3: Strategy
class Oper{
do_work()
}
class Calculator{
strategy: Oper
set_strategy()
calculate()
}

class Adder{
do_work()
}
class Subtractor{
do_work()
}
class Multiplicator{
do_work()
}
class main{
int n
str vvod
}

Adder --> Oper
Subtractor --> Oper
Multiplicator --> Oper
main *--> Oper
main -- Calculator
@enduml
```
### Диаграмма паттерна Стратегия
![alt text](https://github.com/ksu9999/TMP/blob/master/lab3/pr.3.1.png)
### Код программы для реализации паттерна Стратегия
```
# coding=windows-1251
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
```
### Результат реализации паттерна Стратегия
![alt text](https://github.com/ksu9999/TMP/blob/master/lab3/rr.3.1.png)
### Код программы для диаграммы паттерна Шаблонный метод
```
@startuml
title Пратическая работа 3: Template Method
class Statistics{
templateMethod()
pr1()
pr2()
pr3()
pr4()
}

note right of Statistics::"templateMethod()"
self.pr1()
self.pr2()
self.pr3()
self.pr4()
end note

class StudentA{
pr2()
pr3()
}
class  StudentB{
pr1()
pr3()
pr4()
}

Statistics <|-- StudentA 
Statistics <|-- StudentB 

@enduml
```
### Диаграмма паттерна Шаблонный метод
![alt text](https://github.com/ksu9999/TMP/blob/master/lab3/pr.3.2.png)
### Код программы для реализации паттерна Шаблонный метод
```
# coding=windows-1251
from abc import ABC, abstractmethod

class Statistics(ABC):
    
    def templateMethod(self):
        self.pr1()
        self.pr2()
        self.pr3()
        self.pr4()
        
    def pr1(self):
        pass

    def pr2(self):
        pass
    
    @abstractmethod
    def pr3(self):
        pass

    def pr4(self):
        pass

class StudentA(Statistics):
    def pr2(self):
        print("Студент А выполнил практику 2")
    
    def pr3(self):
        print("Студент А выполнил практику 3")

class StudentB(Statistics):
    def pr1(self):
        print("Студент B выполнил практику 1")
    
    def pr3(self):
        print("Студент B выполнил практику 3")

    def pr4(self):
        print("Студент B выполнил практику 4")

def client_call(stat: Statistics):
    stat.templateMethod();

if __name__ == '__main__':
    print("Студент A:")
    client_call(StudentA())
    
    print("Студент B:")
    client_call(StudentB())
```
### Результат реализации паттерна Шаблонный метод
![alt text](https://github.com/ksu9999/TMP/blob/master/lab3/rr.3.2.png)