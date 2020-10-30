###################################################################################
# 특정 언론사 웹 페이지에서 기사 목록(링크)를 스크랩함
# 한 줄에 하나씩 (링크), (제목) 형식으로 기록함
#
# 사용법: [-h] [-p <press>] [-c -n <number> -q <query> -d <detail>] [-s -o <output>] [-l <list]
# -h --help: 도움말
# -p --press [언론] [joongang | donga]
# -c --collect: 기사 목록 검색
#     -n --number [찾을 기사 수]
#     -q --search [주 검색어]
#     -d --detail [부가 포함 검색어]
#     -l --list   (저장할 파일명)
#
# -s --scrap 기사 내용 스크랩
#     -l --list   (기사 목록 파일명)
#     -r --result [출력 파일명]
#
##################################################################################

import sys  # 시스템 모듈
import datetime  # 시각 모듈
import getopt  # 명령행 인수 파서
import inspect  # 텍스트 도구
import csv  # csv 파서
import traceback # 오류 추적 모듈
from threading import Thread # 스레드 모듈
from queue import Queue # 작업 공유용 큐

from press_scraper import JoongangScraper, DongaScraper, ChosunScraper  # 링크 스크래퍼 클래스
from scraper_thread import CollectThread, ScrapThread


def print_help(exit_code):
    """
    커맨드라인 도움말
    """
    print(inspect.cleandoc('''사용법: [-h] [-p <press>] [-c -n <number> -q <query> -d <detail>]
                                      [-s -o <output>] [-l <list>]
                              -h --help: 도움말
                              -p --press [언론] [joongang | donga | chosun]
                              -c --collect: 기사 목록 검색
                                  -n --number [찾을 기사 수]
                                  -q --query [주 검색어]
                                  -d --detail (부가 포함 검색어)
                                  -l --list   (저장할 파일명)

                              -s --scrap 기사 내용 스크랩
                                  -l --list   (기사 목록 파일명)
                                  -r --result (출력 파일명)'''))
    sys.exit(exit_code)


def main(argv):
    """
    메인 루틴
    """

    press = None  # 언론

    collect_article = False  # 기사 수집작업
    number_of_articles = None  # 찾을 기사 수
    query_word = None  # 주 검색어
    detail_word = ''  # 부 검색어

    scrap_article = False  # 기사 스크랩 작업
    result_file_name = None  # 결과 파일명

    list_file_name = None  # 기사 리스트 파일명

    try:  # 명령행 인수 파싱
        opts, _ = getopt.getopt(argv, 'hp:cn:q:d:sr:l:', [
            'help', 'press=', 'collect', 'number=', 'query=', 'detail=', 'scrap', 'result=', 'list='])

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
            collect_article = True
        elif opt in ('-n', '--number'):  # 기사 수
            number_of_articles = int(arg)
        elif opt in ('-q', '--query'):  # 주 검색어
            query_word = arg
        elif opt in ('-d', '--detail'):  # 부 검색어
            detail_word = arg
        elif opt in ('-s', '--scrap'):  # 기사 내용 스크랩
            scrap_article = True
        elif opt in ('-r', '--result'):  # 결과 파일명
            result_file_name = arg
        elif opt in ('-l', '--list'):  # 리스트 파일명
            list_file_name = arg
        else:
            print_help(1)

    # 옵션 확인
    if collect_article is True:
        if (number_of_articles is None) or (query_word is None):  # 기사 수, 주 검색어 입력 안함
            print_help(1)

    if scrap_article is True:
        if (collect_article is False) and (list_file_name is None):  # 수집 작업 없이 리스트 파일 입력 안함
            print_help(1)

    if (collect_article is False) and (scrap_article is False):  # 작업 선택 안함
        print_help(1)

        
    if list_file_name is None:  # 리스트 파일 이름 기본값
        list_file_name = f'articles_list_{datetime.datetime.now().strftime("%Y-%m-%d")}_{press}_{query_word or ""}_{detail_word}.csv'
    if result_file_name is None:  # 기본 출력 파일명 지정
                result_file_name = f'articles_scrap_{datetime.datetime.now().strftime("%Y-%m-%d")}_{press}_{query_word or ""}_{detail_word}.csv'

    # 작업 진행

    # 스크래퍼 선택

    chromedriver_path = './chromedriver'

    if press == 'joongang':
        scraper = JoongangScraper()
    elif press == 'donga':
        scraper = DongaScraper(chromedriver_path)
    elif press == 'chosun':
        scraper = ChosunScraper(chromedriver_path)
    else:
        print_help(1)


    if collect_article is True and scrap_article is True:
        try:
            list_queue = Queue()
            collect_thread = CollectThread(scraper, number_of_articles, query_word, detail_word, list_queue, list_file_name)
            scrap_thread = ScrapThread(scraper, number_of_articles, list_queue, result_file_name)

            collect_thread.start()
            scrap_thread.start()

            collect_thread.join()
            scrap_thread.join()

            print("Process Completed")

        except:
            print("Process error")
        


    
    elif collect_article is True:  # 기사 수집만 진행
        try:
            print('Collecting Articles')

            with open(list_file_name, 'w', encoding='utf8') as file_list:
                list_writer = csv.DictWriter(file_list, ['url', 'title'])
                list_writer.writeheader()

                num = 1 # 횟수 카운터
                for article in scraper.collect_articles(number_of_articles, query_word, detail_word):
                    #파일에 기록
                    #file_list.write(f'{article["url"]}, "{article["title"]}"\n')
                    list_writer.writerow(article)

                    # 작업 상황 출력
                    print(f'Collecting [{num}] {article["url"]}')
                    num += 1

        except KeyboardInterrupt:
            print('Collection Aborted by KeyboardInterrupt')
        except:
            print('Collection Failed')
            traceback.print_exc()

            sys.exit(1)
        

    elif scrap_article is True:  # 기사 스크랩만 진행
        try:
            print('Scrapping Articles')

            with open(result_file_name, 'w', encoding='utf8') as file_result:
                result_writer = csv.DictWriter(file_result, ['date', 'title', 'body'])
                result_writer.writeheader()

                with open(list_file_name, 'r', encoding='utf8') as file_list:
                    list_reader = csv.DictReader(file_list)

                    num = 1  # 횟수 카운터
                    for article in list_reader:
                        url = article['url']
                        content = scraper.scrap_articles(url)  # 내용 스크랩
                        #file_result.write(f'"{content["date"]}", "{content["title"]}", "{content["body"]}"\n')  # 파일 작성
                        result_writer.writerow(content)

                        # 작업 상황 출력
                        print(f'Scraping [{num}] {url}')
                        num += 1

        except KeyboardInterrupt:
            print('Collection Aborted by KeyboardInterrupt')
        except:
            print('Scraping Failed')
            traceback.print_exc()

            sys.exit(1)


if __name__ == '__main__':
    main(sys.argv[1:])
