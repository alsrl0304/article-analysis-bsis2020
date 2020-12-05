import sys


def main(argv):
    merge_file_name = argv[1]
    target_file_name_list = argv[2:]

    if len(target_file_name_list) < 1:
        print("Target Files less than 1")
        sys.exit(1)

    with open(merge_file_name, 'w', encoding='utf8') as merge_file:
        with open(target_file_name_list[0], 'r', encoding='utf8') as target_file_first:
            for line in target_file_first:
                merge_file.write(line)

        for target_file_name in target_file_name_list[1:]:
            with open(target_file_name, 'r', encoding='utf8') as target_file:
                target_file.readline()
                for line in target_file:
                    merge_file.write(line)


if __name__ == "__main__":
    main(sys.argv)
