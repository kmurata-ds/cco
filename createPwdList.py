import pandas as pd
import argparse
import random
import string
import os, sys

def main():
    parser = argparse.ArgumentParser(description='ccoアカウントリストを読み込み、変更用のpwdを付与')
    parser.add_argument('--ccoUsers', help='CCO user CSV file', required=True)
    parser.add_argument('--outFile', help='output csv file',required=True)
    args = parser.parse_args()


    if os.path.exists(args.outFile):
        print("Error, already exist", args.outFile)
        sys.exit()

    # ユーザCSV読み込み
    df = pd.read_csv(args.ccoUsers, encoding='utf-8', sep='\s+')
    df.columns = ["UserPrincipalName"]

    # pwd 追加
    df["passwd"] = [generate_password() for _ in range(len(df))]

    ## 出力 ##
    df.to_csv(args.outFile, sep=",", index=False)

# ランダムな32桁の数字を生成する関数
def random_32_digit_number():
    return ''.join(random.choices('0123456789', k=32))

def generate_password(length=12):
    safe_symbols = '!$%_'
    # 各カテゴリから最低1文字ずつ
    lower = random.choice(string.ascii_lowercase)
    upper = random.choice(string.ascii_uppercase)
    digit = random.choice(string.digits)
    symbol = random.choice(safe_symbols)
    # 残りの文字
    remaining = random.choices(
        string.ascii_letters + string.digits + symbol,
        k=length - 5
    )
    # シャッフルして結合
    password = list(lower + upper + digit + symbol + ''.join(remaining))
    random.shuffle(password)
    # 冒頭は大文字にする.
    initial = random.choice(string.ascii_uppercase)
    return initial + ''.join(password)


if __name__ == '__main__':
    main()