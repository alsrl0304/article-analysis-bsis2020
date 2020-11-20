##################################################################################################
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
##################################################################################################

import sys  # 시스템 모듈
import datetime  # 시각 모듈
import getopt  # 명령행 인수 파서
import inspect  # 텍스트 도구
import csv  # csv 파서
import traceback # 오류 추적 모듈
import queue # 작업 공유용 큐
from threading import Thread # 스레드 모듈

from scraper_press import JoongangScraper, DongaScraper, ChosunScraper  # 링크 스크래퍼 클래스


def print_help(exit_code):
    """
    커맨드라인 도움말
    """
    print(inspect.cleandoc('''사용법: [-h] [-p <press>] [-c -n <number> -q <query> -d <detail> -i <number_ignore>]
                                      [-s -o <output>] [-l <list>]
                              -h --help: 도움말
                              -p --press [언론] [joongang | donga | chosun]
                              -c --collect: 기사 목록 검색
                                  -n --number [찾을 기사 수]
                                  -q --query [주 검색어]
                                  -d --detail (부가 포함 검색어)
                                  -i --ignore (처음부터 무시할 기사 수)
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

    willCollect = False  # 기사 수집작업
    numToCollect = None  # 찾을 기사 수
    queryWord = None  # 주 검색어
    detailWord = ''  # 부 검색어
    numToIgnore = 0

    willScrap = False  # 기사 스크랩 작업
    resultFileName = None  # 결과 파일명

    listFileName = None  # 기사 리스트 파일명

    try:  # 명령행 인수 파싱
        opts, _ = getopt.getopt(argv, 'hp:cn:q:d:i:sr:l:', [
            'help', 'press=', 'collect', 'number=', 'query=', 'detail=', 'ignore=', 'scrap', 'result=', 'list='])

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
            willCollect = True
        elif opt in ('-n', '--number'):  # 기사 수
            numToCollect = int(arg)
        elif opt in ('-q', '--query'):  # 주 검색어
            queryWord = arg
        elif opt in ('-d', '--detail'):  # 부 검색어
            detailWord = arg
        elif opt in ('-i', '--ignore'): # 무시할 기사 수
            numToIgnore = int(arg)
        elif opt in ('-s', '--scrap'):  # 기사 내용 스크랩
            willScrap = True
        elif opt in ('-r', '--result'):  # 결과 파일명
            resultFileName = arg
        elif opt in ('-l', '--list'):  # 리스트 파일명
            listFileName = arg
        else:
            print_help(1)

    # 옵션 확인
    if willCollect is True:
        if (numToCollect is None) or (queryWord is None):  # 기사 수, 주 검색어 입력 안함
            print_help(1)

    if willScrap is True:
        if (willCollect is False) and (listFileName is None):  # 수집 작업 없이 리스트 파일 입력 안함
            print_help(1)

    if (willCollect is False) and (willScrap is False):  # 작업 선택 안함
        print_help(1)

        
    if listFileName is None:  # 리스트 파일 이름 기본값
        listFileName = f'articles_list_{datetime.datetime.now().strftime("%Y-%m-%d")}_{press}_{queryWord or ""}_{detailWord or ""}.csv'
    if resultFileName is None:  # 기본 출력 파일명 지정
                resultFileName = f'articles_scrap_{datetime.datetime.now().strftime("%Y-%m-%d")}_{press}_{queryWord or ""}_{detailWord or ""}.csv'

    # 작업 진행

    # 스크래퍼 선택

    chromedriverPath = './chromedriver'

    if press == 'joongang':
        scraper = JoongangScraper()
    elif press == 'donga':
        scraper = DongaScraper(chromedriverPath)
    elif press == 'chosun':
        scraper = ChosunScraper()
    else:
        print_help(1)


    if willCollect is True and willScrap is True:
        try:
            with open(listFileName, 'w', encoding='utf8') as listFile, \
                open(resultFileName, 'w', encoding='utf8') as resultFile:

                # 큐 제너레이터 함수
                def enqueueIter(queue, num):
                    for _ in range(num):
                        yield queue.get()

                # 작업 큐 및 스레드 생성
                listQueue = queue.Queue() # 작업 큐
                collectThread = Thread(target=collect, args=(
                    scraper, numToCollect, numToIgnore, queryWord, detailWord, listFile,
                    listQueue.put
                ))
                scrapThread = Thread(target=scrap, args=(
                    scraper, resultFile, 
                    enqueueIter(listQueue, numToCollect)
                ))

                # 스레드 시작
                collectThread.start()
                scrapThread.start()

                # 스레드 작업 종료될 때 까지 대기
                collectThread.join()
                scrapThread.join()

            print("Process Completed")

        except KeyboardInterrupt:
            print('Process Aborted by KeyboardInterrupt')
        except:
            print("Process Failed")
            traceback.print_exc()
            sys.exit(1)
        

    elif willCollect is True:  # 기사 수집만 진행
        try:
            with open(listFileName, 'w', encoding='utf8') as listFile:
                collect(scraper, numToCollect, numToIgnore, queryWord, detailWord, listFile)
        except KeyboardInterrupt:
            print('Collection Aborted by KeyboardInterrupt')
        except:
            print('Collection Failed')
            traceback.print_exc()
            sys.exit(1)
        

    elif willScrap is True:  # 기사 스크랩만 진행
        try:
            with open(listFileName, 'r', encoding='utf8') as listFile, \
                open(resultFileName, 'w', encoding='utf8') as resultFile:
                listReader = csv.DictReader(listFile)
                scrap(scraper, resultFile, listReader)
    
        except KeyboardInterrupt:
            print('Scraping Aborted by KeyboardInterrupt')
        except:
            print('Scraping Failed')
            traceback.print_exc()
            sys.exit(1)


def collect(scraper, numToCollect, numToIgnore, queryWord, detailWord, listFile, methodToSave = None):
    print('Collecting Articles')
    listFile.write('"url", "title"\n')

    num = 0 # 횟수 카운터
    skip = numToIgnore # 무시할 기사 수

    try:
        for article in scraper.collectArticles(numToCollect + numToIgnore, queryWord, detailWord):
            num += 1
            
            # 기사 무시
            if skip > 0:
                print(f'Ignoring [{num}] {article["url"]}')
                skip -= 1
                continue

            # 저장
            listFile.write(f'{article["url"]}, "{article["title"]}"\n')
            if methodToSave is not None:
                methodToSave(article)
            
            # 작업 상황 출력
            print(f'Collecting [{num}] {article["url"]}')
        
        print('Collecting Completed')

    except KeyboardInterrupt:
        raise KeyboardInterrupt
    except:
        print(f'Collecting Failed at [{num}]')
        print(f'Ignore it and Resume...')
        collect(scraper, numToCollect - num, num, queryWord, detailWord, listFile, methodToSave)



def scrap(scraper, resultFile, articleSource):
    print('Scraping Articles')
    resultFile.write('"date", "title", "body"\n')

    num = 0  # 횟수 카운터
    for article in articleSource:
        try:
            num += 1

            url = article['url']
            content = scraper.scrapArticles(url)  # 내용 스크랩

            # 저장
            resultFile.write(f'"{content["date"]}", "{content["title"]}", "{content["body"]}"\n')

            # 작업 상황 출력
            print(f'Scraping [{num}] {url}')

        except KeyboardInterrupt:
            raise KeyboardInterrupt
        except:
            print(f'Scraping Failed [{num}] {url}')
            print('Ignore it and Resume...')
            continue

    print('Scraping Completed')
                    

if __name__ == '__main__':
    main(sys.argv[1:])