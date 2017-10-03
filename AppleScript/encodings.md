### Encodings for Applescript

Applescript files are encodied in MacRoman, not utf-8. They should
be editable in Script Editor as is. To edit them in vim, open the
file, and then do

```vim
:e ++enc=MacRoman
```

to load the file with the correct encoding.

