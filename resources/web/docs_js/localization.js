export const lang_spec = {
  "Configure Console URL": {
    "zh_cn": "配置 Console URL"
  },
  "Configure Sense URL": {
    "zh_cn": "配置 Sense URL"
  },
  "Configure Kibana URL": {
    "zh_cn": "配置 Kibana URL"
  },
  "Configure the Elasticsearch Service endpoint URL": {
    "zh_cn": "配置 Elastic Cloud endpoint URL"
  },
  "Configure the Elastic Cloud Enterprise endpoint URL": {
    "zh_cn": "配置 Elastic Cloud Enterprise endpoint URL"
  },
  "Copy as cURL": {
    "zh_cn": "拷贝为 cURL"
  },
  "Couldn't automatically copy!": {
    "zh_cn": "无法自动拷贝!"
  },
  "Default Console URL": {
    "zh_cn": "默认 Console URL"
  },
  "Default Sense URL": {
    "zh_cn": "默认 Sense URL"
  },
  "Default Kibana URL": {
    "zh_cn": "默认 Kibana URL"
  },
  "Enter the URL of the Console editor": {
    "zh_cn": "输入 Console 编辑器的 URL"
  },
  "Enter the URL of the Sense editor": {
    "zh_cn": "输入 Sense 编辑器的 URL"
  },
  "Enter the URL of Kibana": {
    "zh_cn": "输入 Kibana 的 URL"
  },
  "On this page": {
    "zh_cn": "本页导航"
  },
  "Open snippet in Console": {
    "zh_cn": "在 Console 中打开代码片段"
  },
  "Open snippet in Sense": {
    "zh_cn": "在 Sense 中打开代码片段"
  },
  "Or install": {
    "en": 'Or install ',
    "zh_cn": '或安装 '
  },
  ".": {"zh_cn": "。"},
  "editor": {"zh_cn": "编辑器"},
  "host": {"zh_cn": "主办"},
  "username": {"zh_cn": "用户名"},
  "password": {"zh_cn": "密码"},
  "Save": {
    "zh_cn": "保存"
  },
  "This page is not available in the docs for version:": {
    "zh_cn": "当前页在这些版本的文档中不可用："
  },
  "View in Sense": {
    "zh_cn": "在 Sense 中查看"
  },
  "View in Console": {
    "zh_cn": "在 Console 中查看"
  },
  "curl_pw_title": {
    "en": "The password is stored in memory and will be reset after a page reload",
    "zh_cn": "密码存储在内存中，并在页面重新加载后重置"
  }
}

export const lang_strings = lang => phrase_key => {
  const phrase = lang_spec[phrase_key];
  if (!phrase) {
    throw new Error(`Unable to find '${phrase_key}' in the language spec`);
  }

  const translation = phrase[lang];

  if (lang === "en" && !translation) {
    return phrase_key;
  } else if (!!translation) {
    return translation;
  }

  throw new Error(`Unable to find translation entry in '${phrase_key}' for language '${lang}'`);
}
