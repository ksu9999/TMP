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