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