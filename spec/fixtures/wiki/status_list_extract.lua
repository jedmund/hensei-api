--[[
	[''] = { name = '', status = '' },
--]]
local buffs = {
	['DMG Cut'] = {
		page = 'Damage Cut',
		groups = {},
		wiki_comment = '[[Damage Cut]] reducing damage taken.<br />Warning!',
		name = 'DMG Cut',
		detail = 'Taking less DMG',
		icon = 'Status_DMG Cut.png'
	},
	['5% DMG Cut'] = {
		link = 'DMG Cut',
		name = '5% DMG Cut',
		detail = 'Taking 5% less DMG',
		status = '1019_0_5',
	},
	['Dodge All'] = { page = 'Dodge All', name = 'Dodge All', detail = 'Takes no DMG or debuffs while in effect', status = '1019' },
	['Other Self'] = { link = 'Dodge All', },
	['Sun-Touched Paradise'] = {
		page = 'Alanaan#Sun-Touched Paradise',
		wiki_comment = '[[Field effect]]<br />[[Local status effect]]',
		detail = 'ATK is boosted', status = '5018',
	},
	['Wild Card'] = { wiki_comment = [[<table>
<tr><td>long</td></tr></table>]], detail = 'It\'s a "wild" card', status = '9999' },
}
local debuffs = {
	['Blinded'] = { page = 'Blind', name = 'Blinded', detail = 'Attacks have a slight chance to miss', status = '1032' },
	['Accuracy Lowered'] = { page = 'Accuracy Lowered', detail = 'Attacks and special attacks have a chance to miss', status = '1032_4' },
	['Accuracy Lowered 2'] = { link = 'Accuracy Lowered', status = '1032_42' }, -- 2 turns
	['DEF Lowered'] = { page = 'DEF Down', detail = 'DEF is lowered', status = '1020' },
	['DEF Lowered (Local)'] = { link = 'DEF Lowered', status = '1020_11' },
	['DEF Lowered 4'] = { link = 'DEF Lowered (Local)', status = '1020_14' },
}
local effects = {
	['Charge Bar'] = { page = 'Charge Boost', wiki_detail = 'Instantly boosts [[Charge Bar]] by %a%', status = '1061' },
	['Charge Boost'] = { link = 'Charge Bar', },
}
local aliases = {
	['DEF Down 4'] = 'DEF Lowered 4',
	['5% Cut'] = '5% DMG Cut',
}

return {
	['aliases'] = aliases,
	['buffs'] = buffs,
	['debuffs'] = debuffs,
	['effects'] = effects
}
