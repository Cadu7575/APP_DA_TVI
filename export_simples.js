var token = null;
var req = indexedDB.open("firebaseLocalStorageDb");
req.onsuccess = function(e) {
  var db = e.target.result;
  var tx = db.transaction("firebaseLocalStorage", "readonly");
  var store = tx.objectStore("firebaseLocalStorage");
  store.getAll().onsuccess = function(ev) {
    var items = ev.target.result;
    var auth = items.find(function(i) { return i.fbase_key && i.fbase_key.indexOf(":authUser:") > -1; });
    if (auth && auth.value) {
      token = auth.value.stsTokenManager && auth.value.stsTokenManager.accessToken;
      console.log("Token OK:", token ? token.substring(0,30) + "..." : "nao encontrado");
      if (token) buscarDados(token);
    } else {
      console.log("Nao logado ou token nao encontrado");
    }
  };
};

function buscarDados(tk) {
  var h = {"Authorization": "Bearer " + tk};
  var base = "https://firestore.googleapis.com/v1/projects/copafacil-web/databases/(default)/documents/";
  var resultado = {campeonatos: [], times: [], jogadores: [], partidas: [], lances: []};

  function val(v) {
    if (!v) return null;
    if (v.stringValue !== undefined) return v.stringValue;
    if (v.integerValue !== undefined) return +v.integerValue;
    if (v.booleanValue !== undefined) return v.booleanValue;
    if (v.timestampValue !== undefined) return v.timestampValue;
    if (v.mapValue) { var o={}; for(var k in v.mapValue.fields) o[k]=val(v.mapValue.fields[k]); return o; }
    if (v.arrayValue) return (v.arrayValue.values||[]).map(val);
    return null;
  }

  function toObj(doc) {
    var o = {};
    for (var k in doc.fields) o[k] = val(doc.fields[k]);
    o._id = doc.name.split("/").pop();
    return o;
  }

  function get(path, cb) {
    fetch(base + path + "?pageSize=500", {headers: h})
      .then(function(r) { return r.json(); })
      .then(function(d) { cb(d.documents || []); })
      .catch(function() { cb([]); });
  }

  function baixar() {
    var blob = new Blob([JSON.stringify(resultado, null, 2)], {type: "application/json"});
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = "copafacil_export.json";
    a.click();
    console.log("RESUMO: Campeonatos=" + resultado.campeonatos.length + " Times=" + resultado.times.length + " Jogadores=" + resultado.jogadores.length + " Partidas=" + resultado.partidas.length);
    console.log("Arquivo copafacil_export.json baixado! Salve na pasta TVI.");
  }

  // Tenta ler campeonatos de varias colecoes
  var colecoes = ["championships", "campeonatos"];
  var done = 0;

  colecoes.forEach(function(col) {
    get(col, function(docs) {
      if (docs.length > 0) {
        console.log(col + ": " + docs.length + " docs encontrados");
        var objs = docs.map(toObj);
        resultado.campeonatos = resultado.campeonatos.concat(objs);

        var pd = 0;
        objs.forEach(function(camp) {
          var sub = ["teams","equipes","times"];
          sub.forEach(function(sc) {
            get(col + "/" + camp._id + "/" + sc, function(tdocs) {
              if (tdocs.length > 0) {
                var times = tdocs.map(toObj);
                resultado.times = resultado.times.concat(times.map(function(t) { t._campId = camp._id; return t; }));
                times.forEach(function(time) {
                  ["players","jogadores"].forEach(function(sj) {
                    get(col + "/" + camp._id + "/" + sc + "/" + time._id + "/" + sj, function(jdocs) {
                      if (jdocs.length > 0) {
                        resultado.jogadores = resultado.jogadores.concat(jdocs.map(function(d) { var o=toObj(d); o._timeId=time._id; o._campId=camp._id; return o; }));
                      }
                    });
                  });
                });
              }
            });
            ["matches","partidas","games","jogos"].forEach(function(sp) {
              get(col + "/" + camp._id + "/" + sp, function(pdocs) {
                if (pdocs.length > 0) {
                  var parts = pdocs.map(toObj);
                  resultado.partidas = resultado.partidas.concat(parts.map(function(p) { p._campId = camp._id; return p; }));
                  parts.forEach(function(part) {
                    ["events","lances","eventos"].forEach(function(sl) {
                      get(col + "/" + camp._id + "/" + sp + "/" + part._id + "/" + sl, function(ldocs) {
                        if (ldocs.length > 0) {
                          resultado.lances = resultado.lances.concat(ldocs.map(function(d) { var o=toObj(d); o._partidaId=part._id; return o; }));
                        }
                      });
                    });
                  });
                }
              });
            });
          });
        });
      }
      done++;
      if (done >= colecoes.length) {
        setTimeout(baixar, 5000);
      }
    });
  });
}
