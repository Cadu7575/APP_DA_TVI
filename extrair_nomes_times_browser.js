// ════════════════════════════════════════════════════════════
// EXTRATOR COMPLETO DE NOMES — TVI News App
// Cole no Console do Chrome (copafacil.com logado)
// O token já foi capturado em window._cfToken
// ════════════════════════════════════════════════════════════
(async () => {
  const CF_RTDB = 'https://copafacil-web.firebaseio.com';
  const TVI_PROJECT = 'tvi-news';
  const TVI_API_KEY = 'AIzaSyAAqZ5f_SqNL0nZbR1Kq8FHYLDzXiyH-3E';

  // Pegar token da CopáFácil do IndexedDB
  async function getCfToken() {
    return new Promise(resolve => {
      const req = indexedDB.open('firebaseLocalStorageDb');
      req.onsuccess = e => {
        try {
          const db = e.target.result;
          const tx = db.transaction('firebaseLocalStorage', 'readonly');
          tx.objectStore('firebaseLocalStorage').getAll().onsuccess = e => {
            for (const item of e.target.result) {
              if (item.value && item.value.stsTokenManager && item.value.stsTokenManager.accessToken) {
                resolve(item.value.stsTokenManager.accessToken);
                return;
              }
            }
            resolve(null);
          };
        } catch(ex) { resolve(null); }
      };
      req.onerror = () => resolve(null);
    });
  }

  // Autenticar no TVI News
  async function getTviToken() {
    const email = localStorage.getItem('flutter.email') || 'lalomoraes@copafacil.com';
    const pass = localStorage.getItem('flutter.pass') || 'L@lO2@25';
    const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${TVI_API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: pass, returnSecureToken: true })
    });
    const d = await r.json();
    return d.idToken || null;
  }

  // Buscar nome de um time no RTDB da CopáFácil
  async function getTeamName(teamId, token) {
    const paths = [`/teams/${teamId}`, `/t/${teamId}`, `/orgs/${teamId}`];
    for (const path of paths) {
      const r = await fetch(`${CF_RTDB}${path}.json?auth=${token}`);
      const d = await r.json();
      if (d && !d.error) {
        const nome = d.n || d.name || d.nome || d.title || d.nm || d.team_name;
        if (nome && typeof nome === 'string') return nome;
        if (typeof d === 'string') return d;
      }
    }
    return null;
  }

  // Salvar nome no Firestore do TVI
  async function salvarTime(teamId, nome, tviToken) {
    await fetch(`https://firestore.googleapis.com/v1/projects/${TVI_PROJECT}/databases/(default)/documents/times/${teamId}`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${tviToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: { id: { stringValue: teamId }, nome: { stringValue: nome } } })
    });
  }

  // IDs de todos os times
  const TEAM_IDS = ["-OTEO90wspe87SxIsQ6-","-OTEOAJmch_2ysbCGrVw","-OTEOBAPCI6JAY9P3O0h","-OTEOCZGFJigaIFPyj_F","-OTEhi-cAvJMSmrC78xu","-OTEhj0I8P2hFKs0AUzm","-OTEhm7RpwTAeEbdElCF","-OTEi1-7eWsOCf1rl1WY","-OTEi21PsxYJoixN5U8H","-OTEi3YrdNSXwrjDd2nY","-OTEi40T5YYFg4pP7RVQ","-OTEiSXWrIhG36GR2Ck8","-OTEiTd2Y3UGTH4OzBwt","-OTEioE52gFpMEPXPIqI","-OTEipC1pJjt44EqSNB3","-OTEiqZimIaKi6r5O-dX","-OTEis9YAWF9W2bqkAEF","-OTEitxZuibbXVIYILPa","-OTEiuAqJAGtlKzEOJe4","-OTEiy3-Y2j4OKN5M-yN","-OTEj0D29amJNQJ-dKqt","-OTEj1Zq_rDm_Pnx4UoJ","-OTEj3L0YQNJ-bkTDZBb","-OTEj4L0GEijfJvP0V4-","-OTEj8MFnUc3x7cMYrWP","-OTEjDPHOFqAaXX2x6DM","-OTEjFTCpnHdBkK3FQMB","-OTEjGHZHzRdKe0Pw5Kc","-OTEjHzxPtXJrknSGNzP","-OTEjI9_F7ZsXopFv8qG","-OWFvk_1jot0RsHw5ezS","-OWFwFoN0ImTkW8TF85-","-OWFwWAsfEIOpCRhzv8W","-OWGvq_QTESr1kH0MILO","-OWGvv7lIiLcQ-AvZF-t","-OWGvzmWfTwJs4_1R_Nj","-OWGw0UWMiwzbPRclc0u","-OWGw1VOK3FLaDHKFSez","-OWGw3jGm9nX_10rqgKm","-OWGw4Y8Xu1U5qZkc4WQ","-OWGwFid3MFW70eTgFRt","-OWGwK48WXV28WBdBKvR","-OWGwPQA-7PRhu3-XxDR","-OWGwfJuSbSj3kxZe13b","-OWGwyxt7BOG2Su28CjR","-OWHKPHV_A7BH9C27vMl","-OWHPE8r8pUMmGbvgHLL","-OWHPhcz5yvT5A2IKswJ","-OWHPtBsIFaOdVPSh61d","-OWHQ2hjeKvVoY7xHqUD","-OWHQ8H8lw2cHBOzRCyF","-OWL5t_BNyen1E8KyYfr","-OWLBn6ncWXenvmwxYi1","-OWLG7c3hgnovTCRX32o","-OWLGH0JNmIHWXobezTj","-OWLGSgvHhcVWgkL-0SM","-OWLGXKBy0yNEUbxRMKT","-OWLG_hnL2wJVRAoB1sA","-OWLGerIZIPPg3HJmapV","-Oy4w-HfkiAJjMdifXsU","-Oy4w1tICXrtSZ1_98se","-Oy4w6nT4EVRuPOnCOWb","-Oy4wC4OttSqmxEtt6w0","-Oy4wGo3qXvnKFoCnDnm","-Oy4wKzbprAjXQx4FrJZ","-Oy5-F4ih60HIu_KsfDx","-Oy5-F4ih60HIu_KsfDy","-Oy5-F4ih60HIu_KsfE-","-Oy5-F4ih60HIu_KsfE0","-Oy5-F4ih60HIu_KsfE1","-Oy5-F4ih60HIu_KsfE2","-Oy5-F4ih60HIu_KsfE3","-Oy5-F4ih60HIu_KsfE5","-Oy5-F4ih60HIu_KsfE6","-Oy5-F4jxWxzRkajT3WN","-Oy5-F4jxWxzRkajT3WO","-Oy5-F4jxWxzRkajT3WP","-Oy5-F4jxWxzRkajT3WQ","-Oy5-F4jxWxzRkajT3WR","-Oy50WuUmt9f6pIhQkqE","-Oy51BnAb3R5L0UHFZLf","-Oy51N4c5mXf2T5M2ktv","-Oy51RrA43NShAD7JpV1","-Oy51VPKHoeSMW2ue3-h","-Oy525ad_TOIOTaY1cON","-Oy8mgpG-_-KaV4cadfW","-Oy8mgpG-_-KaV4cadfY","-Oy8mgpG-_-KaV4cadfZ","-Oy8mgpG-_-KaV4cadf_","-Oy8mgpG-_-KaV4cadfa","-Oy8mgpG-_-KaV4cadfb","-Oy8mgpG-_-KaV4cadfc","-Oy8mgpHoDCnWQ-o4gJq","-Oy8mgpHoDCnWQ-o4gJt","-Oy8mgpHoDCnWQ-o4gJv","-Oy8mgpHoDCnWQ-o4gJw","-Oy8mgpHoDCnWQ-o4gJx","-Oy8mgpHoDCnWQ-o4gJy","-Oy8mgpHoDCnWQ-o4gJz","-Oy8mgpHoDCnWQ-o4gK-","-Oy8mgpHoDCnWQ-o4gK0","-Oy8mgpHoDCnWQ-o4gK2","-Oy8mgpHoDCnWQ-o4gK3","-Oy8mgpHoDCnWQ-o4gK4","-Oy8mgpHoDCnWQ-o4gK5","-Oy8mgpHoDCnWQ-o4gK7","-Oy8mgpHoDCnWQ-o4gK8","-Oy8mgpHoDCnWQ-o4gK9","-Oy8mgpHoDCnWQ-o4gKD","-Oy8nfFSv01gqZL4w5oU","-Oy8o2RYNh5i5vKTmCQ1","-Oy8on7JjvVpZK3g3O3O","-Oy8pQHyD3SOM07uM47h","-Oy8phR-m_GkZaTy_iJQ","-Oy8q7-b8eKHYYb_R4wq","-Oy8qTpA-8o7BXuF43HI","-Oy8sk4eYF8DosuCNGXh","-Oy8sk4eYF8DosuCNGXi","-Oy8sk4eYF8DosuCNGXj","-Oy8sk4eYF8DosuCNGXm","-Oy8sk4eYF8DosuCNGXn","-Oy8sk4eYF8DosuCNGXp","-Oy8sk4eYF8DosuCNGXq","-Oy8sk4eYF8DosuCNGXr","-Oy8sk4eYF8DosuCNGXs","-Oy8sk4eYF8DosuCNGXt","-Oy8sk4eYF8DosuCNGXv","-Oy8sk4eYF8DosuCNGXw","-Oy8sk4eYF8DosuCNGXy","-Oy8sk4fS6_98FhO-4Ip","-Oy8sk4fS6_98FhO-4Is","-Oy8sk4fS6_98FhO-4It","-Oy8sk4fS6_98FhO-4Iu","-Oy8sk4fS6_98FhO-4Iw","-Oy8taqkBKOahcd-DEz9","-Oy8uKFHY_cFoYhZpvnN","-Oy8ukIG86Xf9NG13ZNd","-Oy8vboVkApLZUqbQQp3","-Oy8vqNAt2lyi9B-70ed","-Oy8wY3qxzUJO2xCR_4Q","-Oy8wlYI6l4TH_bsQrGO","-Oy8xB1fDr4d9rvZYhuZ","-Oy8xGeTuRBaj-UoHVS-","-Oy8xkmVEe2W1lp-D8DS","-Oy8y-afC3hjZ6mm-avT","-Oy8yKD_134jlNV3XlYH","-Oy8yoMUWte01dSiwiRg","-Oy8z1LEmAJsFuVDARKG","-Oy8zLtpuaD_40akuOly","-Oy9--RTBYdEsnfHCcmI","-Oy9--RTBYdEsnfHCcmM","-Oy9--RTBYdEsnfHCcmO","-Oy9--RTBYdEsnfHCcmP","-Oy9--RTBYdEsnfHCcmQ","-Oy9--RTBYdEsnfHCcmR","-Oy9--RTBYdEsnfHCcmS","-Oy9--RTBYdEsnfHCcmU","-Oy9--RTBYdEsnfHCcmY","-Oy9--RTBYdEsnfHCcm_","-Oy9--RTBYdEsnfHCcma","-Oy9--RTBYdEsnfHCcmb","-Oy9--RTBYdEsnfHCcme","-Oy9--RTBYdEsnfHCcmf","-Oy9--RTBYdEsnfHCcmo","-Oy9-AFBBSg9zK6vdPL-","-Oy9-Ua0RpbBvQeQcMdU","-Oy9-wv1pitEq52y0qyB","-Oy90R99oVbSQybGgQAu","-Oy91HOo2l4FAvf7s-Cs","-Oy91eOrZbHIZOQh2Doz","-Oy932Ru7kGZtK9g1KLA","-Oy93Tm-V0dGleNukDsp","-Oy93Tm-V0dGleNukDsv","-Oy93Tm-V0dGleNukDsw","-Oy93Tm-V0dGleNukDt0","-Oy93Tm-V0dGleNukDt4","-Oy93Tm-V0dGleNukDt5","-Oy93Tm-V0dGleNukDt6","-Oy93lGgp0AS7JeNDe4f","-Oy943Jd7o0wZbc3WLU8","-Oy94d9gu8LqKVcGkoT3","-Oy94uJ6U8cLmlE3S9RZ","-Oy964C_vgziE3ae4kMh","-Oy96VNsxH_F2zG9KHhX","-Oy9yq64KPYqMeFhT6zK","-Oy9zW4xSh2PdvJiYo-e","-OyA-31WfHIshhiG2OuM","-OyA-zan1M5fDQ75Sy6y","-OyA0YgM2MwUYXzn_9YG","-OyA0oTOUJX73NqA80k-","-OyA14MX-iV1DPEtgFEf","-OyA1Qtj0ro1y4Jaq7An","-OyA2VTGIyLWgzDT2Hu7","-OyA2VTGIyLWgzDT2Hu8","-OyA2VTHoJyfZ2V7PYf5","-OyA4P1nzEyYmAvo5rVI","-OyA5hnQ_4r1EsNIPJym","-OyA6HIT6bDxCwK3sPU3","-OyA6kNMighpUHfJgtsn","-OyA73UhGKbNkxVhPD3b","-OyA7vMgp56kBx5QyhsA","-OWLBpqIa9-EbDnhhU-d","-OWLGR1BF-VRjxXaNGpI","-OWLG8O4VBw-_w6h6AZr","-OWFvnHs0fXgrk4R8oFM","-OWFvu2kSo_br76DRhYP","-OWFvy-UxIzR-GQEMi2_","-OWFw1YkA6Bqp8XklBDl","-OWFw4hreBOamrMVJsas","-OWFw6hOD3AVjOi64V7W","-OWFw9XkFcZnCIvOSIVT","-OWFwCxsrDJqObR42Ck2","-OWFwLBtFtjEORPlg2e2","-OWFwcOcqaV4w2MedNtx","-OWFwlHUDBLV4rzXbC7F","-OWFwoVVYvbZVQeQcqv_","-OWFws-7lf1WIhTURHQz","-OWFxBCU7cOclw3hJSZi","-OWFxHcrc952VNy3vy9t","-OWFxMLV41tIG0A1Fp-v","-OWFxVRU9EfdVRN53DXh","-OWFx_LV0Xuu8O9rIYQN","-OWGvscelWuD4KLUZ-3G","-OWGvwb1COh5_K-Hjixb","-OWGw5oXBgLvjpDS2Vyc","-OWGw8HOH7q-eulVmcK0","-OWGw9g9m1oAnd18662T","-OWGwB6dLNAwKDZwkbYy","-OWGwHGmOK8L5pRtp0GY","-OWGwMXdZIsKGyUIETlG","-OWGwO8m644hp0YzzXdd","-OWGwcHP0twQjJ590AfJ","-OWGwdG0jrwdXLUBYYFl","-OWGwj1dcqZBHpfNBWnT","-OWGwotmpdkA-QE4olr5","-OWGwqpeC24UGjgyg-QU","-OWGwuSO61lV8bT8sEsT","-OWGwwOPqf-ASsBfVCuz","-OWGwyOHqJxg2TCyI64T","-OWGx-DWYFBI8DwHgb9x","-OWGx050r9wiHEjWUQe0","-OWHFSmsE9pgcBz7Gh98","-OWHFU1OqSwMSsFyvQeU","-OWHFVKdwjmgHx28pun4","-OWHFX38qnAHft4OLcDZ","-OWHFYEVMzak4YxF62TK","-OWHF_bdlM2YYRJ_1FN5","-OWHFaMO50LbjktK7f0n","-OWHFc8tye500nblSHh2","-OWHKCQFLebrZLWl1oH1","-OWHKDpkG2x5Au6zFxWy","-OWHKG-7YuMgv9ZfmbAm","-OWHKJlkKvBVMQSFAc3q","-OWHKKhVjy-f5cn88c5W","-OWHKN0Vvytv44h1CdS-","-OWHKQpF9jSVHgN7ZR_X","-OWHKS-l-Ue0CrAOi-0b","-OWHKT78w7JJD0cbf2ty","-OWHKVp7CXysbF1VLiqE","-OWHKXokTB8UEUY0IezO","-OWHKYeFWfiBpyTBJ_ER","-OWHKZiVz8v29mbUVtqC","-OWHKcLFcEe-rUFSI56D","-OWHKjos2GVamquQ9ubV","-OWHKkfcxD0nuWPXLOyk","-OWHKlw7s_TFJKZBxMs3","-OWHKnBunX_APWT9Va3m","-OWHKqgjZN2bjGlWdTnr","-OWHKsJVuxLSGG3wLsEr","-OWHKtg80d3xRts4bqsm","-OWHKudk-NGPm4Au88PV","-OWHKwx-zzP220Tma83G","-OWHLJJ7eZeaggbEMcbE","-OWHP9qbA9C8W9IidWAZ","-OWHPBAUV_dRP5zKLp54","-OWHPC6MwmbpKL9CUawd","-OWHPFIG1IEEj3iAtoYS","-OWHPH4M2Q6-5Ux0WYlN","-OWHPM4EqaOye7672JcQ","-OWHPMxFuuo836sFGPIx","-OWHPO0NN2XyNHw8O66K","-OWHPPPM5vCsC6oi5T1h","-OWHPRMOa1jVhRgZHMla","-OWHPShEGJ7AXFNhFnxG","-OWHPUbcNiwu9AtZhCec","-OWHPY_MsuWHuFWyS8zH","-OWHP_mcA8PvoQzk4lmt","-OWHPcIr57pFrTHueDv4","-OWHPe2XpjPvpACe1Swm","-OWHPfuj9lpwm_mXGgmq","-OWHPrBk1W_IdDXCicfh","-OWHPujn_jO8Ognf7P61","-OWHPvqj3ZzACVaRRJO5","-OWHPxMUrMOZxpx6_Tus","-OWHQ1U73D5ivaElUBQn","-OWHQ41XuSy1juh4phv_","-OWHQ5JVEnugynOmTBSL","-OWHQ79bhjcipMsb-HkB","-OWL5MkQmsB-4LKBOmCc","-OWL5O7of-s3ayyUYQBk","-OWL5OzvFy19o6GuRYz2","-OWL5RZ3H-LFJQGF_5DU","-OWL5VHQzK8_gCYCrgUj","-OWL5VzfqJ9RDx9TXEpG","-OWL5XDw0fiSTinF7z6T","-OWL5XuvfSs98o-BmJlW","-OWL5am2Lxi4G6NZDnbT","-OWL5ea2Tt0M03GpI2Zk","-OWL5ifQENBmFD0mKRNX","-OWL5kofPmkN48GDoKI1","-OWL5nJoAhx7XOOD7Zfs","-OWL5nsZzkeg6mQQCWbn","-OWL5pfgal2MUJzq6V7J","-OWL5r3nHlSUMD6_TUtC","-OWL5sZ3fFAhKgDDRppj","-OWL5uEn6FJVV6WZye7C","-OWL5viod5_5RYkmGV5F","-OWL5x8RY8DG8-9LEt_N","-OWL5xpRNvXLPrm84XD4","-OWL8YcQ_rumO8KwPlq5","-OWL8ZgfwM8lwhk4zoT-","-OWL8_dBK_w7YOJbvw14","-OWL8aeQB5228A-1PZi8","-OWL8bW2aFCcpu9bZQYE","-OWL8dRvkxxlyWs-2onX","-OWL8eVpM5fSS_taparM","-OWL8fXnvbpiLjduOGzJ","-OWL8hTZ1c3DeOKRSpC8","-OWL8i03X6UbBJYomzOo","-OWL8kDZA3hBiWGtGHJZ","-OWL8ndRCZUd9UqofGBG","-OWL8opnS4NKaXlCFmBy","-OWL8qRf1hHI789SJNHM","-OWL8rzvDxPTI80i3q-H","-OWL8tsffWMLVRRW5sNL","-OWLA86YSdbjsg43C92h","-OWLA9LIOoea22hbavvw","-OWLACpAfHV6ExdIVzlS","-OWLAOqnv7ZsKIS3-9en","-OWLASRQhWP4uXAcSWzs","-OWLBmSnFiUZZAjzM_lM","-OWLBoUBgnSFkSW8TKYT","-OWLBrAQC4-KqZiuyh8A","-OWLBtBBmSAoGqfQMC1f","-OWLBvTIXnbDi6eff9T3","-OWLBxjSFhkGznHMdCQ6","-OWLByqIg-oStUGeCMDN","-OWLC-FvWh5GXOUYuRYT","-OWLEaM32sxzHxJhW6BG","-OWLEbpQvkU8Ib3K17vO","-OWLG9fBrZKcnsbOHrFY","-OWLGCxBKeKpFvXOWtce","-OWLGRRAlOkALMj-cekS","-OWLGYwRDqS9zijO4MZ2","-OWLGaU3i8oMFDNShgGW","-OWLGj-AUIKXUQRsI_8i","-OWLGkY23pPRNMH4ykXw","-OTEinfndUvld_H7hMKm","-OTEiu1hkuBoM-YBB3uj","-OTEivBniMeC12PigFVH","-OTEivhUNlc5BMfchW8c","-OTEiwQySG2FZWsS67JJ","-OTEj5QlMI6BRby7QnAo","-OTEj6GkonTDO5CtU8oe","-OTEj7r2IuHmtLocDuH4","-OTEj9Ez5pa04GE9uHzh","-OTEjENhHyL2nf7ZWfcY","-OTEjFfgnqK0nOlDx2u_","-OTEjGykGbWejWGrDj8o","-OWLAW6n3QxRUKLVkW0a","-OWLGfd2_OX8K603cjpU","-OwZ6CfQ1-5J2RvazWSv","-OwZ6GYTBcUHM0JfgiIo","-OwZ6K5unjLZQ1DveZlu","-OwZ6Ox1fAK_pf9S11Pi","-OwZ6REsGTgFFyJEuWmr","-OwZ6TqHbKsZKU9mVe8j","-OwZ6V_I8eXdKO0PtKml","-OwZ6Zy907lrCoxkkR9A","-OwZ6a8wvjsVkBDjNd2D","-OwZ6btdz9vujZVpaaZQ","-OwZ6fQZcz7GH5PYqqFu"];

  // ── INÍCIO ──────────────────────────────────────────────────
  console.log('🚀 Iniciando extração de', TEAM_IDS.length, 'times...');
  
  const cfToken = await getCfToken();
  if (!cfToken) { console.error('❌ Token CopáFácil não encontrado no IndexedDB. Execute o script de captura primeiro.'); return; }
  console.log('✅ Token CopáFácil OK');

  const tviToken = await getTviToken();
  if (!tviToken) { console.error('❌ Falha ao autenticar no TVI News'); return; }
  console.log('✅ Token TVI News OK');

  const teamMap = {};
  let found = 0, notFound = 0;
  
  // Testar primeiro 1 time para ver se o token funciona
  const testName = await getTeamName(TEAM_IDS[0], cfToken);
  console.log('🧪 Teste:', TEAM_IDS[0], '->', testName);
  
  if (!testName) {
    console.warn('⚠️ Teste falhou. O token do IndexedDB pode não ter permissão para /teams. Tentando ler de outra rota...');
    // Tentar rota alternativa: /events/{campId}/t/{teamId}
    const campIds = ['-jcgq9', '-o3bpO', '-rmjb0', '-077g4', '-5fqd2'];
    for (const campId of campIds) {
      const r = await fetch(`${CF_RTDB}/events/${campId}/t/${TEAM_IDS[0]}.json?auth=${cfToken}`);
      const d = await r.json();
      console.log(`Rota /events/${campId}/t/${TEAM_IDS[0]}:`, JSON.stringify(d).substring(0,100));
    }
    return;
  }
  
  // Processar todos os times
  for (let i = 0; i < TEAM_IDS.length; i++) {
    const id = TEAM_IDS[i];
    const nome = await getTeamName(id, cfToken);
    if (nome) {
      teamMap[id] = nome;
      found++;
      await salvarTime(id, nome, tviToken);
      if (found % 25 === 0) console.log(`  ✓ ${found} times salvos (${i+1}/${TEAM_IDS.length})...`);
    } else {
      notFound++;
    }
    if (i % 5 === 0) await new Promise(r => setTimeout(r, 50));
  }

  console.log('\n✅ CONCLUÍDO!');
  console.log(`   ✓ ${found} times com nome salvo no TVI News`);
  console.log(`   ✗ ${notFound} times sem acesso`);
  window._teamMap = teamMap;
  console.table(teamMap);
})();
