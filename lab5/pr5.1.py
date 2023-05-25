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