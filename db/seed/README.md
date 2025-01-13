# Adding items to the database

Anyone can add data to the database via a Pull Request on Github. Fork the repository, then create a new CSV file in the
`updates` folder with the date, type of item you're updating, and the next number in the sequence. The most important
part is the type of item, which should be plural for convention. This is what tells the service how to process your
data.

```
20240618-characters-001.csv
20241231-weapons-010.csv
20250115-summons-025.csv
```

It's recommended to use a CSV editor to edit this data, but something like Microsoft Excel or Numbers should work fine
too.

## Required values

You are required to set values for the following fields:
TBA

## Arrays

When adding the `character_id`, `nicknames_en`, or `nicknames_jp`, make sure to wrap your values in brackets ({}). If
there are multiple values, you can separate them with a comma (,) with no spaces on either side.

```
# character_id, Zeta and Vaseraga (Halloween):
{3024,3025}

# nicknames_en, Threo
{sarasa,cake,thalatha}
```

## Value tables

Values for properties like `element` are pre-defined, so you only need to input the corresponding digit.

#### Rarity

| Rarity | Value |
|--------|-------|
| SSR    | 3     |
| SR     | 2     |
| R      | 1     |

#### Element

| Element | Value |
|---------|-------|
| Wind    | 1     |
| Fire    | 2     |
| Water   | 3     | 
| Earth   | 4     |
| Dark    | 5     |
| Light   | 6     | 

#### Proficiency

| Proficiency | Value |
|-------------|-------|
| Sabre       | 1     |
| Dagger      | 2     |
| Axe         | 3     |
| Spear       | 4     |
| Bow         | 5     | 
| Staff       | 6     |
| Melee       | 7     |
| Harp        | 8     |
| Gun         | 9     |
| Katana      | 10    |

#### Race

| Race    | Value |
|---------|-------|
| Unknown | 0     |
| Human   | 1     |
| Erune   | 2     |
| Draph   | 3     |
| Harvin  | 4     |
| Primal  | 5     |

#### Gender

| Gender      | Value |
|-------------|-------|
| Other       | 0     |
| Male        | 1     |
| Female      | 2     |
| Male/Female | 3     | 

#### Weapon Series

| Series Name | Value |
|-------------|-------|

#### Summon Series

| Series Name | Value |
|-------------|-------|

### Wiki links

You should try to provide identifiers for the 4 major wikis: gbf.wiki, gbf-wiki.com (JA), Kamigame (JA) and Gamewith (
JA). Here's how:

#### gbf.wiki

This is simply the item's name, as it appears after `https://gbf.wiki/` in the URL.

```
https://gbf.wiki/Bahamut -> Bahamut
```

#### Gamewith

This is a 5 to 6 digit string that appears at the end of the URL.

```
https://xn--bck3aza1a2if6kra4ee0hf.gamewith.jp/article/show/21612 -> 21612
```

#### Kamigame

Use a [URL decoder](https://www.urldecoder.org/) to extract the Japanese characters from the URL after the final forward
slash (/) and before `.html`.

```
https://kamigame.jp/%E3%82%B0%E3%83%A9%E3%83%96%E3%83%AB/%E3%82%AD%E3%83%A3%E3%83%A9%E3%82%AF%E3%82%BF%E3%83%BC/SSR%E3%83%A4%E3%83%81%E3%83%9E.html 
-(decoder)-> 
https://kamigame.jp/グラブル/キャラクター/SSRヤチマ.html
-(value)->
SSRヤチマ
```

#### gbf-wiki.com

Use a [URL decoder](https://www.urldecoder.org/) to extract the Japanese characters from the URL after the question
mark. Replace the `+` with a space.

```
https://gbf-wiki.com/?%E3%83%A4%E3%83%81%E3%83%9E+(SSR)%E3%83%AA%E3%83%9F%E3%83%86%E3%83%83%E3%83%89%E3%83%90%E3%83%BC%E3%82%B8%E3%83%A7%E3%83%B3
-(decoder)-> 
https://gbf-wiki.com/?ヤチマ+(SSR)リミテッドバージョン
-(value)->
ヤチマ (SSR)リミテッドバージョン
```
