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
