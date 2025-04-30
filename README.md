# BadFriend Infostealer👹
A Powershell infostealer that uses Discord to exfiltrate sensitive Data.

![finalThumbnail](https://github.com/user-attachments/assets/3103b146-27a2-418c-8034-c165793fd091)


## Overview👀
This tool was created using Powershell and uses various methods to exfiltrate data.
Currently, it can exfiltrate the following information:

- Wi-Fi credentials
- Chromium based browsers credentials(to decrypt them, use `decrypt.py`)
- Browsing history
- Cookies

## Demo📽

🔗 https://youtu.be/zQyf3deMcZw

## Usage😼
To exfiltrate data, the tool creates temporary files on the host machine, which are deleted after the exfiltration process. These files are then uploaded to a Discord server specified by you.
Hence, to use the tool you need to set up a Discord server👻

In the video below (starting at second 45), I explain how to create a Discord server and a webhook. It takes less than one minute.

🔗 https://www.youtube.com/watch?v=1OHCafosyZs

Once the server is set up, you can run the tool however you prefer. In the demo, I used a **USB Rubber Ducky** configured using this [repository](https://github.com/dbisu/pico-ducky?tab=readme-ov-file).

## Disclaimer🚨

This tool is provided strictly for **educational and research purposes**. I am not responsible for any misuse. Unauthorized access to systems and data is illegal. Use this responsibly and only in environments where you have explicit permission.

👾 **Enjoy hacking (ethically)!** If you find bugs or have suggestions, feel free to contribute!

💬 **Join the community!** Have questions or want to chat? Join my Discord server: [Join here](https://discord.com/invite/ZRf5PJYGMk)

## To-do👷🏽‍♂️
- Currently, when the tool exfiltrate the cookies, it opens the browsers for some seconds to make an API call and then it closes them. You can set the flag `--headless` when you want to open a browser with Powershell which would be useful to achieve complete stealthy, but I can't call the method `Network.getAllCookies` when that mode is enable. Any ideas?💡
