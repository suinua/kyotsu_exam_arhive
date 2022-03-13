import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;

void main() async {
  var urls = [//制限くらうかもしれないから1個1個やって
    //'https://web.archive.org/web/20140903085440/http://www.dnc.ac.jp/data/kakomondai.html',//平成24,25,26
    //'https://web.archive.org/web/20170912205434/http://www.dnc.ac.jp/data/kakomondai.html',//平成27,28,29
    //'https://web.archive.org/web/20200816161303/https://www.dnc.ac.jp/center/kakomondai.html',//平成30,31,令和2
    'https://www.dnc.ac.jp/kyotsu/kakomondai.html',//共通テスト
  ];

  //最新年度だけfromArchive:false
  urls.forEach((url) => downloadFromPage('C:/kyotsu/', url, fromArchive: true));
}

void downloadFromPage(String saveDirectoryPath, String url,{bool fromArchive = true}) async {
  final saveDirectory = Directory(saveDirectoryPath);
  await saveDirectory.create();

  var response = await http.get(Uri.parse(url));
  var home = parse(response.body);
  await Future.forEach<Element>( home.getElementsByTagName('a'), (anchorElement) async {
    if (anchorElement.text.contains(RegExp('年度(.*)(の問題|の正解)'))) {
      var year = anchorElement.text.replaceFirst(RegExp('度(.*)'), '').replaceAll(RegExp('( |　)'), '');
      await downloadFromPdfPage(saveDirectory.path + '$year/', anchorElement.attributes['href']!, fromArchive: fromArchive);
    }
  });
}

Future<void> downloadFromPdfPage(String theYearSaveDirectoryPath, String url, {bool fromArchive = true}) async {
  final theYearSaveDirectory = Directory(theYearSaveDirectoryPath);
  await theYearSaveDirectory.create();

  http.Response? response;

  try {
    response = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'KyotsuExam/1.0.0',
      'Connection': 'keep-alive',
      'Accept-Encoding': 'gzip, deflate, br',
      'Accept': '*/*'
    });
  } catch (e) {
    print('error : $url');
  }

  if (response != null) {
    if (response.statusCode == 200) {
      final html = parse(response.body);
      final title = html.getElementsByClassName('cp-h1-text cp-all')[0].text;
      print('200 : $title $url');
      final directory = Directory(theYearSaveDirectory.path + title.replaceFirst(RegExp('(.*)年度'), ''));
      await directory.create();
      await Future.forEach<Element>(html.getElementsByTagName('a'),
          (element) async {
        if (element.attributes.keys.contains('href')) {
          final downloadUrl = fromArchive
              ? 'https://web.archive.org' + element.attributes['href']!
              : 'https://www.dnc.ac.jp' + element.attributes['href']!;
          final isPdf = downloadUrl.contains('pdf');
          final isMp3 = downloadUrl.contains('mp3');
          if (isPdf || isMp3) {
            final extension = isPdf ? '.pdf' : 'mp3';
            final fileName =
                element.text.replaceAll(RegExp(r'\((.*)\)'), '') + extension;
            await saveFile(downloadUrl, directory.path, fileName);
          }
        }
      });
    } else {
      print('${response.statusCode} : $url');
    }
  }
}

Future<void> saveFile(String url, String path, String fileName) async {
  try {
    var downloadResponse = await http.get(Uri.parse(url), headers: {
      'Connection': 'keep-alive',
      'Accept-Encoding': 'gzip, deflate, br',
      'Accept': '*/*'
    });
    var file = File('$path/$fileName');
    if (file.existsSync()) {
      if (file.lengthSync() < downloadResponse.bodyBytes.lengthInBytes) {
        await file.writeAsBytes(downloadResponse.bodyBytes);
      } else {
        print('not save : path->$path/$fileName, url->${Uri.decodeFull(url)}');
      }
    } else {
      await file.writeAsBytes(downloadResponse.bodyBytes);

    }
  } catch (e) {
    print('download error : path->$path/$fileName, url->${Uri.decodeFull(url)}');
  }
}
