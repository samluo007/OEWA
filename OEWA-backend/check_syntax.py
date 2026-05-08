import ast
import sys

try:
    with open('main.py', 'r', encoding='utf-8') as f:
        code = f.read()
    ast.parse(code)
    print("语法正确")
except SyntaxError as e:
    print(f"语法错误 at line {e.lineno}: {e.msg}")
    print(f"文本: {e.text}")
    # 打印错误行附近的代码
    lines = code.split('\n')
    start = max(0, e.lineno - 3)
    end = min(len(lines), e.lineno + 2)
    for i in range(start, end):
        marker = ">>> " if i == e.lineno - 1 else "    "
        print(f"{marker}{i+1}: {lines[i]}")
