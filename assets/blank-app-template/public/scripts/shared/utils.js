// Utility methods
var util = {
    GUID: function()
    {
        var S4 = function ()
        {
            return Math.floor(
                    Math.random() * 0x10000 /* 65536 */
                ).toString(16);
        };

        return (
                S4() + S4() + "-" +
                S4() + "-" +
                S4() + "-" +
                S4() + "-" +
                S4() + S4() + S4()
            );
    },
    html: {
        encode: function (value){
          return $('<div/>').text(value).html();
        },
        decode: function (value){
          return $('<div/>').html(value).text();
        }
    },
    convert: {
            toBool: function(string){
                switch(string.toLowerCase()){
                    case "true": case "yes": case "1": return true;
                    case "false": case "no": case "0": case null: return false;
                    default: return Boolean(string);
            }
        },
            /**
            Convert to a Intrger
            @param a string to conver to Int
            @return: {int} 0 if NULL
            */
            toInt: function(test) {
                var tmp = parseInt(test, 10);

                if (isNaN(tmp))
                  tmp = 0;

                return tmp;
            }
    },
    file: {
        exists: function (f){
            var pathToFile = new air.File(f);
            if (pathToFile.exists) {
                return true
            } else {
                air.trace("Does not exist: "+ pathToFile.nativePath);
                return false;
            }
        },
        read: function (f){
            var pathToFile = new air.File(f);
            var returnTxt = "";
            
            if (pathToFile.exists) {
                var stream = new air.FileStream();
                stream.open(pathToFile, air.FileMode.READ);
                returnTxt = stream.readUTFBytes(stream.bytesAvailable);
                stream.close();
            } else {
                air.trace("No such file:"+ pathToFile.nativePath);
            }
            
            return returnTxt;
        },
        write: function (f, contents){
            var pathToFile = new air.File(f);

            var stream = new air.FileStream();
            stream.open(pathToFile, air.FileMode.WRITE);
            stream.writeUTFBytes(contents);
            stream.close();

            return contents;
        },
        toString: function(f){
            return f.nativePath.replace(/ /g,"%20");
        }
    }
};
//page methods
var page = {
        request: {
            querystring: function(name) {
                return decodeURI(
                    (RegExp(name + '=' + '(.+?)(&|$)').exec(location.search)||[,null])[1]
                );
            }
        },
        openExternalURL: function (href) {
           var request = new air.URLRequest(href);
           try {
             air.navigateToURL(request);
           } catch (e) {
             console.log(e);
           }
        }
};
