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

