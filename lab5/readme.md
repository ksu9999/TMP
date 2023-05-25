# Практическая работа №4. Абстрактная фабрика. Посредник. Строитель. Адаптер
### Код программы для диаграммы паттерна Абстрактная фабрика
```
@startuml
title Пратическая работа 5: Abstract Factory

class main{
create_factory(objectname)
create_Socks()
}

class SocksAbstractFactory{
getSocks(self)
}

class RedSocksFactory{
getSocks(self)
}

class  BlackSocksFactory{
getSocks(self)
}

class RedSocks{
init()
create(self)
}

class BlackSocks{
init()
create(self)
}

class Socks{
init()
create(self)
}

main->SocksAbstractFactory
SocksAbstractFactory<- RedSocksFactory
SocksAbstractFactory<-BlackSocksFactory

RedSocksFactory..>RedSocks
RedSocks->Socks
BlackSocksFactory..>BlackSocks
BlackSocks-down->Socks
@enduml
```
### Диаграмма паттерна Абстрактная фабрика
![alt text](https://github.com/ksu9999/TMP/blob/master/lab5/pr5.1.png)
### Код программы для реализации паттерна Абстрактная фабрика
```
# coding=windows-1251
from abc import ABC, abstractmethod

class Socks(ABC):
    def __init__(self, object: str):
        self._object = object

    @abstractmethod
    def create(self): pass


class RedSocks(Socks):
    def __init__(self):
        super().__init__("Красные")

    def create(self):
        print(f'Сделаны носки: {self._object}')





class BlackSocks(Socks):
    def __init__(self):
        super().__init__("Черные")

    def create(self):
        print(f'Сделаны носки: {self._object}')





class SocksAbstractFactory(ABC):
    @abstractmethod
    def getSocks(self) -> Socks: pass




class RedSocksFactory(SocksAbstractFactory):
    def getSocks(self) -> Socks:
        return RedSocks()




class BlackSocksFactory(SocksAbstractFactory):
    def getSocks(self) -> Socks:
        return BlackSocks()

class Application:
    def __init__(self, table: SocksAbstractFactory):
        self._Socks_table = table

    def create_Socks(self):
        Socks = self._Socks_table.getSocks()
        Socks.create()


def create_factory(objectname: str) -> SocksAbstractFactory:
    tabled = {
        "Красные": RedSocksFactory,
        "Черные": BlackSocksFactory
    }
    return tabled[objectname]()



objectname = "Красные"
cr = create_factory(objectname)
app = Application(cr)
app.create_Socks()


objectname = "Черные"
cr = create_factory(objectname)
app = Application(cr)
app.create_Socks()
```
### Результат реализации паттерна Абстрактная фабрика
![alt text](https://github.com/ksu9999/TMP/blob/master/lab5/rr5.1.png)
### Код программы для диаграммы паттерна Посредник
```
@startuml
title Пратическая работа 5: Mediator

class main{
printl()
mediator = ChatMediator()
user1 = ConcreteUser()
user2 = ConcreteUser()
user3 = ConcreteUser()
user4 = ConcreteUser()
}

class User{
init()
send(self, msg)
sendA(self, msg)
sendB(self, msg)
receive(self, msg)
}

class ChatMediator{
init()
add_user(self, user)
send_message(self, msg, user)
send_messageA(self,msg,user)
send_messageB(self,msg,user)
}

class ConcreteUser{
send(self, msg)
sendA(self, msg)
sendB(self, msg)
receive(self, msg)
}

main->User
User<..ConcreteUser
User<..ChatMediator
ChatMediator *--> ConcreteUser
@enduml
```
### Диаграмма паттерна Посредник
![alt text](https://github.com/ksu9999/TMP/blob/master/lab5/pr5.2.png)
### Код программы для реализации паттерна Посредник
```
# coding=windows-1251
from abc import ABC, abstractmethod

class User():
    def __init__(self, med, name, pol):
        self.mediator = med
        self.name = name
        self.pol = pol

    @abstractmethod
    def send(self, msg):
        pass

    @abstractmethod
    def sendA(self, msg):
        pass

    @abstractmethod
    def sendB(self, msg):
        pass

    @abstractmethod
    def receive(self, msg):
        pass

class ChatMediator:
    def __init__(self):
        self.users = []

    def add_user(self, user):
        self.users.append(user)

    def send_message(self, msg, user):
        for u in self.users:
            if u != user:
                u.receive(msg)

    def send_messageA(self,msg,user):
        for u in self.users:
            if u != user and u.pol == "A":
                u.receive(msg)

    def send_messageB(self,msg,user):
        for u in self.users:
            if u != user and u.pol == "B":
                u.receive(msg)

class ConcreteUser(User):
    def send(self, msg):
        print(self.name + ": Отправил сообщение: " + msg)
        self.mediator.send_message(msg, self)

    def sendA(self, msg):
        print(self.name + ": Отправил группе А: " + msg)
        self.mediator.send_messageA(msg, self)

    def sendB(self, msg):
        print(self.name + ": Отправил группе В: " + msg)
        self.mediator.send_messageB(msg, self)

    def receive(self, msg):
        print(self.name + ": Получено сообщение: " + msg)

def printl():
    print("-" * 50)


mediator = ChatMediator()

user1 = ConcreteUser(mediator, "Иван", "A")
user2 = ConcreteUser(mediator, "Кристина", "A")
user3 = ConcreteUser(mediator, "Максим", "B")
user4 = ConcreteUser(mediator, "Егор", "B")

mediator.add_user(user1)
mediator.add_user(user2)
mediator.add_user(user3)
mediator.add_user(user4)

user1.send("Вы в команде")
printl()

user1.sendA("Вы в группе А")
printl()

user1.sendB("Вы в группе В")
printl()
```
### Результат реализации паттерна Посредник
![alt text](https://github.com/ksu9999/TMP/blob/master/lab5/rr5.2.png)
### Код программы для диаграммы паттерна Строитель
```
@startuml
title Пратическая работа 5: Builder

class main{
director = Director()
int a
}

class Director{
init()
set_builder(self, builder: Builder)
make_bur(self)
}

class Builder{
add_sauce(self)
add_meal(self)
add_topping(self)
add_cheese(self)
prepare_botbread(self)
get_bur(self)
}

class  Cheeseburger{
init()
add_sauce(self)
add_meal(self)
add_topping(self)
add_cheese(self)
prepare_botbread(self)
get_bur(self)
}

class Humburger{
init()
add_sauce(self)
add_meal(self)
add_topping(self)
add_cheese(self)
prepare_botbread(self)
get_bur(self)
}

class Burger{
init()
printer(self)
}

class Product{
}

main->Director
Director->Builder
Builder<..Cheeseburger
Builder<..Humburger
Cheeseburger-down->Burger
Humburger->Burger
Burger->Product
@enduml
```
### Диаграмма паттерна Строитель
![alt text](https://github.com/ksu9999/TMP/blob/master/lab5/pr5.3.png)
### Код программы для реализации паттерна Строитель
```
# coding=windows-1251
from abc import ABC, abstractmethod


class Product:
    bread = ['Кунжутные', 'Обычные']
    meal = ['Две котлеты', 'Котлета']
    nam = ['Помидоры', 'Огурцы']
    cheese = ['Сыр', 'Без сыра']
    souse = ['Кетчуп', 'Майонез']


class Burger:
    def __init__(self, name):
        self.name = name

        self.meal = None
        self.topping = []
        self.cheese = None
        self.souse = None
        self.botbread = None

    def printer(self):
        print(f'Название:{self.name}\n' \
              f'Булочки:{self.botbread}\n'\
              f'Мясо:{self.meal}\n' \
              f'Топинги:{[it for it in self.topping]}\n' \
              f'Сыр:{self.cheese}\n' \
              f'Соус:{self.souse}\n')
              

class Builder(ABC):

    @abstractmethod
    def add_sauce(self) -> None: pass

    @abstractmethod
    def add_meal(self) -> None: pass

    @abstractmethod
    def add_topping(self) -> None: pass

    @abstractmethod
    def add_cheese(self) -> None: pass

    @abstractmethod
    def prepare_botbread(self) -> None: pass

    @abstractmethod
    def get_bur(self) -> Burger: pass


class Director:
    def __init__(self):
        self.builder = None

    def set_builder(self, builder: Builder):
        self.builder = builder

    def make_bur(self):
        if not self.builder:
            raise ValueError("Builder didn't set")

        self.builder.add_sauce()
        self.builder.add_meal()
        self.builder.add_topping()
        self.builder.add_cheese()
        self.builder.prepare_botbread()


class Cheeseburger(Builder):
    def __init__(self):
        self.bur = Burger("Чизбургер")


    def add_sauce(self) -> None:
        self.bur.souse = Product.souse[0]

    def add_meal(self) -> None:
        self.bur.meal = Product.meal[1]

    def add_topping(self) -> None:
        self.bur.topping.append(Product.nam[1])

    def add_cheese(self) -> None:
        self.bur.cheese = Product.cheese[0]

    def prepare_botbread(self) -> None:
        self.bur.botbread = Product.bread[0]

    def get_bur(self) -> Burger:
        return self.bur


class Humburger(Builder):
    def __init__(self):
        self.bur = Burger("Гамбургер")


    def add_sauce(self) -> None:
        self.bur.souse = Product.souse[0]

    def add_meal(self) -> None:
        self.bur.meal = Product.meal[1]

    def add_topping(self) -> None:
        self.bur.topping.append(Product.nam[1])

    def add_cheese(self) -> None:
        self.bur.cheese = Product.cheese[1]

    def prepare_botbread(self) -> None:
        self.bur.botbread = Product.bread[0]

    def get_bur(self) -> Burger:
        return self.bur

director = Director()
print("Введите, чтобы собрать чизбургер - 1, гамбургер - 2")
a=int(input())
if a==1:
    builder = Cheeseburger()
else:
    builder = Humburger()
director.set_builder(builder)
director.make_bur()
burger = builder.get_bur()
burger.printer()
```
### Результат реализации паттерна Строитель
![alt text](https://github.com/ksu9999/TMP/blob/master/lab5/rr5.3.png)
### Код программы для диаграммы паттерна Адаптер
```
@startuml
title Пратическая работа 5: Mediator

class main{
ad = AdapterEuroInUsa()
us = UsaSocket()
}

class UsaFork{
power_usa(self)
}

class EuroFork{
power_euro(self)
}

class UsaSocket{
init()
connect(self)
}

class AdapterEuroInUsa{
init()
power_usa(self)
}

main->UsaSocket
main<..AdapterEuroInUsa
AdapterEuroInUsa->EuroFork
UsaSocket -> UsaFork
@enduml
```
### Диаграмма паттерна Адаптер
![alt text](https://github.com/ksu9999/TMP/blob/master/lab5/pr5.4.png)
### Код программы для реализации паттерна Адаптер
```
class UsaFork:
    def power_usa(self):
        print('power on. Usa')

class EuroFork:
    def power_euro(self):
        print('power on. Euro')

class UsaSocket:
    def __init__(self, fork):
        self.fork = fork
    def connect(self):
        self.fork.power_usa()

class AdapterEuroInUsa:
    def __init__(self):
        self._euro_fork = EuroFork()
    def power_usa(self):
        self._euro_fork.power_euro()

uf = UsaFork() 
us = UsaSocket(uf) 
us.connect() 

ad = AdapterEuroInUsa()
us = UsaSocket(ad)
us.connect() 
```
### Результат реализации паттерна Адаптер
![alt text](https://github.com/ksu9999/TMP/blob/master/lab5/rr5.4.png)