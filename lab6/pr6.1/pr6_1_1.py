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