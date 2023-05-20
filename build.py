import os
import sys
import json


def log(type, message):
    print(f"[{type}]\t{message}")


def build(input, output):
    log("INFO", "正在打开配置文件。")

    try:
        command = json.load(open("config.json", "r"))["luac"]
    except:
        command = "luac"
        log("WARN", "无法打开配置文件，设置为默认值！")

    command += f" -o {output} {input}"

    log("INFO", "正在执行构建：" + command)

    os.system(command)

    log("INFO", "构建成功！正在修改文件 Header。")

    with open(output, "rb") as fr:
        file = fr.read()
        with open(output, "wb") as fw:
            fw.write(file[:12]+b'\x04'+file[14:])

    log("INFO", "修改完成！")


def usage():
    print("""WindSeed 快速构建工具
使用方法：
    build.py <input> <output>        - 构建 Luac 文件。""")


if len(sys.argv) != 3:
    usage()
else:
    build(sys.argv[1], sys.argv[2])
