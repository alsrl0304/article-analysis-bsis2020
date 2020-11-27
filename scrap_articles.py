##################################################################################################
# 특정 언론사 웹 페이지에서 기사 목록(링크)를 스크랩함
# 한 줄에 하나씩 (링크), (제목) 형식으로 기록함
#
# 사용법: [-h] [-p <press>] [-c -n <number> -q <query> -d <detail>] [-s -r <result>] [-l <list>]
# -h --help: 도움말
# -p --press [언론] [joongang | donga]
# -c --collect: 기사 목록 검색
#     -q --search [주 검색어]
#     -d --detail [부가 포함 검색어]
#     -n --number [찾을 기사 수]
#     -i --ignore (처음부터 무시할 기사 수)
#     -l --list   (저장할 파일명)
#
# -s --scrap 기사 내용 스크랩
#     -l --list   (기사 목록 파일명)
#     -r --result (출력 파일명)
#
##################################################################################################

import sys  # 시스템 모듈
import datetime  # 시각 모듈
import getopt  # 명령행 인수 파서
import inspect  # 텍스트 도구
import csv  # csv 파서
import traceback  # 오류 추적 모듈
import queue  # 작업 공유용 큐
from threading import Thread  # 스레드 모듈

from scraper_press import JoongangScraper, DongaScraper, ChosunScraper  # 링크 스크래퍼 클래스


# 커맨드라인 도움말 출력 및 종료
def print_help(exit_code):
    print(inspect.cleandoc(
        '''사용법: [-h] [-p <press>] [-c -q <query> -d <detail> -n <number> -i <ignore>] [-s -r <result>] [-l <list>]
            -h --help: 도움말
            -p --press [언론] [joongang | donga]
            -c --collect: 기사 목록 검색
                -q --search [주 검색어]
                -d --detail [부가 포함 검색어]
                -n --number [찾을 기사 수]
                -i --ignore (처음부터 무시할 기사 수)
                -l --list   (저장할 파일명)

            -s --scrap 기사 내용 스크랩
                -l --list   (기사 목록 파일명)
                -r --result (출력 파일명)'''))
    sys.exit(exit_code)


# 메인 루틴
def main(argv):

    press = None  # 언론

    will_collect = False  # 기사 수집작업
    collect_count = None  # 찾을 기사 수
    query_word = None  # 주 검색어
    detail_word = ''  # 부 검색어
    ignore_count = 0

    will_scrap = False  # 기사 스크랩 작업
    result_file_name = None  # 결과 파일명

    list_file_name = None  # 기사 리스트 파일명

    try:  # 명령행 인수 파싱
        opts, _ = getopt.getopt(argv, 'hp:cn:q:d:i:sr:l:', [
            'help', 'press=', 'collect', 'number=', 'query=',
            'detail=', 'ignore=', 'scrap', 'result=', 'list='])

    except getopt.GetoptError as error:  # 오류 발생 (잘못된 입력)
        print(error)
        print_help(1)

    for opt, arg in opts:
        if opt in ('-h', '--help'):  # 도움말
            print_help(0)
        elif opt in ('-p', '--press'):  # 언론
            if arg in ('joongang', 'donga', 'chosun'):
                press = arg
            else:
                print_help(1)
        elif opt in ('-c', '--collect'):  # 기사 목록 수집
            will_collect = True
        elif opt in ('-n', '--number'):  # 기사 수
            collect_count = int(arg)
        elif opt in ('-q', '--query'):  # 주 검색어
            query_word = arg
        elif opt in ('-d', '--detail'):  # 부 검색어
            detail_word = arg
        elif opt in ('-i', '--ignore'):  # 무시할 기사 수
            ignore_count = int(arg)
        elif opt in ('-s', '--scrap'):  # 기사 내용 스크랩
            will_scrap = True
        elif opt in ('-r', '--result'):  # 결과 파일명
            result_file_name = arg
        elif opt in ('-l', '--list'):  # 리스트 파일명
            list_file_name = arg
        else:
            print_help(1)

    # 옵션 확인
    if will_collect is True:
        if (collect_count is None) or (query_word is None):  # 기사 수, 주 검색어 입력 안함
            print_help(1)

    if will_scrap is True:
        if (will_collect is False) and (list_file_name is None):  # 수집 작업 없이 리스트 파일 입력 안함
            print_help(1)

    if (will_collect is False) and (will_scrap is False):  # 작업 선택 안함
        print_help(1)

    if list_file_name is None:  # 리스트 파일 이름 기본값
        list_file_name = f'articles_list_{datetime.datetime.now().strftime("%Y-%m-%d")}_{press}_{query_word or ""}_{detail_word or ""}.csv'
    if result_file_name is None:  # 기본 출력 파일명 지정
        result_file_name = f'articles_scrap_{datetime.datetime.now().strftime("%Y-%m-%d")}_{press}_{query_word or ""}_{detail_word or ""}.csv'

    # 작업 진행

    # 스크래퍼 선택

    chromedriver_path = './chromedriver'

    if press == 'joongang':
        scraper = JoongangScraper()
    elif press == 'donga':
        scraper = DongaScraper(chromedriver_path)
    elif press == 'chosun':
        scraper = ChosunScraper()
    else:
        print_help(1)

    if will_collect is True and will_scrap is True:
        try:
            with open(list_file_name, 'w', encoding='utf8') as list_file, \
                    open(result_file_name, 'w', encoding='utf8') as result_file:

                list_file.write('"url", "title"\n')
                result_file.write('"date", "title", "body"\n')

                # 작업 큐 및 스레드 생성
                article_queue = queue.Queue()
                collect_thread = Thread(target=collect, args=(
                    scraper, collect_count, ignore_count, query_word, detail_word, list_file,
                    article_queue.put
                ))
                scrap_thread = Thread(target=scrap, args=(
                    scraper, result_file, article_queue
                ), daemon=True)

                # 스레드 시작
                collect_thread.start()
                scrap_thread.start()

                # 스레드 작업 종료될 때 까지 대기
                collect_thread.join()
                article_queue.join()

            print("Process Completed")

        except KeyboardInterrupt:
            print('Process Aborted by KeyboardInterrupt')
        except:
            print("Process Failed")
            traceback.print_exc(file=sys.stdout)
            sys.exit(1)

    elif will_collect is True:  # 기사 수집만 진행
        try:
            with open(list_file_name, 'w', encoding='utf8') as list_file:
                list_file.write('"url", "title"\n')

                collect(scraper, collect_count, ignore_count,
                        query_word, detail_word, list_file)

        except KeyboardInterrupt:
            print('Collection Aborted by KeyboardInterrupt')
        except:
            print('Collection Failed')
            traceback.print_exc(file=sys.stdout)
            sys.exit(1)

    elif will_scrap is True:  # 기사 스크랩만 진행
        try:
            with open(list_file_name, 'r', encoding='utf8') as list_file, \
                    open(result_file_name, 'w', encoding='utf8') as result_file:
                list_reader = csv.DictReader(list_file)

                result_file.write('"date", "title", "body"\n')

                # 작업 큐 생성 및 스레드 생성
                article_queue = queue.Queue()

                def enqueue_list_reader():
                    for article in list_reader:
                        article_queue.put(article)

                read_thread = Thread(target=enqueue_list_reader)
                scrap_thread = Thread(target=scrap, args=(
                    scraper, result_file, article_queue), daemon=True)

                # 스레드 시작
                read_thread.start()
                scrap_thread.start()

                # 스레드 작업 종료까지 대기
                read_thread.join()
                article_queue.join()

        except KeyboardInterrupt:
            print('Scraping Aborted by KeyboardInterrupt')
        except:
            print('Scraping Failed')
            traceback.print_exc(file=sys.stdout)
            sys.exit(1)

# 수집 수행


def collect(scraper, collect_count, ignore_count, query_word, detail_word,
            list_file, method_save=None):
    print('Collecting Articles')

    num = 1  # 기사 카운터

    print(f'Ignoring {ignore_count} Articles...')

    try:
        for article in scraper.collect_articles(collect_count, ignore_count,
                                                query_word, detail_word):

            # 저장
            list_file.write(f'{article["url"]}, "{article["title"]}"\n')
            if method_save is not None:
                method_save(article)

            # 작업 상황 출력
            print(f'Collected [{num}] {article["url"]}')
            num += 1

        print('Collecting Completed')

    except KeyboardInterrupt:
        raise KeyboardInterrupt
    except:
        print(f'Collecting Failed at [{num}] ')
        traceback.print_exc(limit=3, file=sys.stdout)
        print('Ignore it and Resume...')
        collect(scraper, collect_count - num - 1, ignore_count + num, query_word,
                detail_word, list_file, method_save)

# 스크래핑 수행


def scrap(scraper, result_file, article_source_queue):
    print('Scraping Articles')

    num = 0  # 횟수 카운터
    while True:
        try:
            num += 1

            article = article_source_queue.get()
            url = article['url']
            content = scraper.scrap_articles(url)  # 내용 스크랩

            # 저장
            result_file.write(
                f'"{content["date"]}", "{content["title"]}", "{content["body"]}"\n')

            # 작업 상황 출력
            print(f'Scraped [{num}] {url}')

            article_source_queue.task_done()

        except KeyboardInterrupt:
            raise KeyboardInterrupt
        except:
            print(f'Scraping Failed [{num}] {url}')
            traceback.print_exc(limit=3, file=sys.stdout)
            print('Ignore it and Resume...')
            continue

    print('Scraping Completed')


if __name__ == '__main__':
    main(sys.argv[1:])
