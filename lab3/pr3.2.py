
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