# Практическая работа №6. Инверсия управления. Заместитель. Компоновщик.
### Код программы для реализации паттерна Инверсия управления
#### pr_1_1.py
```
# coding=windows-1251

print("Продуктовая корзина")

product = []
numbers=[]
def add_c():
    for person in product:
        print(f"Добавили: {person}.")

def calculation(sum=0):
    for num in numbers:
        sum=num+sum
    print(sum)


product.append("Яблоко")
product.append("Банан")
add_c()

numbers.append(10)
numbers.append(8)
calculation()
```
#### pr_1_2.py
```
# coding=windows-1251
from pr6_1_1 import * 

print("product.py:")

product.append("Сыр")
product.append("Молоко")

numbers.append(248)
numbers.append(75)

add_c()
calculation()
```
### Результат реализации паттерна Инверсия управления
![alt text](https://github.com/ksu9999/TMP/blob/master/lab5/rr6.1.png)
### Код программы для диаграммы паттерна Заместитель
```
@startuml
title Пратическая работа 6: Proxy

class main{
client(user: User)
real_user = Real()
proxy = Proxy(real_user)
}

class User{
ex(self)
}

class Real{
ex(self)
}

class Proxy{
init()
ex(self)
access(self)
}

class PasswordService{
init()
get(self)
}

main->User
User<.. Real
User<..Proxy
Proxy->Real
main -down-> PasswordService
@enduml
```
### Диаграмма паттерна Заместитель
![alt text](https://github.com/ksu9999/TMP/blob/master/lab5/pr6.2.png)
### Код программы для реализации паттерна Заместитель
```
# coding=windows-1251

from abc import ABC, abstractmethod


class PasswordService:
    def __init__(self, password):
        self.password = password

    def get(self):
        return self.password

class User(ABC):

    @abstractmethod
    def ex(self) -> None:
        pass


class Real(User):
    def ex(self) -> None:
        print("Настоящая часть кода запущена\n123-23 =", 123-23)


class Proxy(User):

    def __init__(self, real_user: Real) -> None:
        self._real_user = real_user

    def ex(self) -> None:

        if self.access():
            self._real_user.ex()

    def access(self) -> bool:
        realpassword = 12345
        print("Proxy: Проверяю наличие доступа")
        if realpassword == password.get():
            return True
        else:
            print("Вы не допущены, неверный пароль")
            return False


def client(user: User) -> None:
    user.ex()


if __name__ == "__main__":
    print("Запуск без Proxy:")
    real_user = Real()
    client(real_user)

    password = PasswordService(123)
    print("\nЗапуск с Proxy и неверным паролем:")
    proxy = Proxy(real_user)
    client(proxy)

    password = PasswordService(12345)
    print("\nЗапуск с Proxy и верным паролем:")
    proxy = Proxy(real_user)
    client(proxy)
```
### Результат реализации паттерна Заместитель
![alt text](https://github.com/ksu9999/TMP/blob/master/lab5/rr6.2.png)
### Код программы для диаграммы паттерна Компоновщик
```
@startuml
title Пратическая работа 6: Composite

class main{
    Hi = Element()
    Item1 = Element()
    Item2 = Element()
    Item3 = Element()
    Item4 = Element()
    Item11 = Leaf()
    Item12 = Leaf()
    Item21 = Leaf()
    Item22 = Leaf()
    Item31 = Leaf()
    Item32 = Leaf()
    Item41 = Leaf()
    Item42 = Leaf()
    Item43 = Leaf()
    Item44 = Leaf()
}

class Leaf{
init()
show(self)
showNum(self)
}

class Element{
init()
add(self, child)
remove(self, child)
show(self)
showNum(self)
}

main<.. Leaf
main<..Element
Element*->main

@enduml
```
### Диаграмма паттерна Компоновщик
![alt text](https://github.com/ksu9999/TMP/blob/master/lab5/pr6.3.png)
### Код программы для реализации паттерна Компоновщик
```
# coding=windows-1251

class Leaf:
    def __init__(self, number, *args):
        self.number = number
        self.position = args[0]


    def show(self):
        print("\t", end="")
        print(self.position)

    def showNum(self):
        print("\t", end="")
        print(self.number)


class Element:
    def __init__(self, number, *args):
        self.number = number
        self.position = args[0]
        self.children = []

    def add(self, child):
        self.children.append(child)

    def remove(self, child):
        self.children.remove(child)

    def show(self):
        print(self.position)
        for child in self.children:
            print("\t", end="")
            child.show()

    def showNum(self):
        print(self.number)
        for child in self.children:
            print("\t", end="")
            child.showNum()



if __name__ == "__main__":
    Hi = Element("A1", "Генерал")
    Item1 = Element("B1", "Майор 1")
    Item2 = Element("B2", "Майор 2")
    Item3 = Element("B3", "Майор 3")
    Item4 = Element("B3", "Майор 4")
    Item11 = Leaf("C1", "Рядовой 11")
    Item12 = Leaf("C2", "Рядовой 12")
    Item21 = Leaf("C3", "Рядовой 21")
    Item22 = Leaf("C4", "Рядовой 22")
    Item31 = Leaf("C5", "Рядовой 31")
    Item32 = Leaf("C6", "Рядовой 32")
    Item41 = Leaf("C7", "Рядовой 41")
    Item42 = Leaf("C8", "Рядовой 42")
    Item43 = Leaf("C9", "Рядовой 43")
    Item44 = Leaf("C10", "Рядовой 44")

    Item1.add(Item11)
    Item1.add(Item12)
    Item2.add(Item21)
    Item2.add(Item22)
    Item3.add(Item31)
    Item3.add(Item32)
    Item4.add(Item41)
    Item4.add(Item42)
    Item4.add(Item43)
    Item4.add(Item44)

    Hi.add(Item1)
    Hi.add(Item2)
    Hi.add(Item3)
    Hi.add(Item4)
    Hi.show()
    print("Номера:")
    Hi.showNum()
```
### Результат реализации паттерна Компоновщик
![alt text](https://github.com/ksu9999/TMP/blob/master/lab5/rr6.3.png)
