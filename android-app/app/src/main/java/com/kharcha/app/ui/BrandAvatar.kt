package com.kharcha.app.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kharcha.app.R

/**
 * Brand logo with letter fallback. Word-boundary match, longest key wins —
 * "Slice Credit" must not hit "lic", "South Indian Bank" must not hit "indian bank".
 */
@Composable
fun BrandAvatar(merchant: String, emoji: String, size: androidx.compose.ui.unit.Dp = 40.dp) {
    val resId = remember(merchant) { brandResId(merchant) }
    Box(
        modifier = Modifier.size(size).clip(CircleShape)
            .background(if (resId != null) Color.White else MaterialTheme.colorScheme.primaryContainer),
        contentAlignment = Alignment.Center,
    ) {
        if (resId != null) {
            Image(
                painter = painterResource(id = resId),
                contentDescription = merchant,
                modifier = Modifier.fillMaxSize().padding(6.dp),
            )
        } else {
            Text(emoji, fontSize = 20.sp)
        }
    }
}

private fun String.containsWord(key: String): Boolean {
    var i = indexOf(key)
    while (i >= 0) {
        val before = i - 1
        val after = i + key.length
        if ((before < 0 || !this[before].isLetterOrDigit()) &&
            (after >= length || !this[after].isLetterOrDigit())
        ) return true
        i = indexOf(key, i + 1)
    }
    return false
}

private fun brandResId(merchant: String): Int? {
    val n = merchant.lowercase()
    if (n.containsWord("cred")) return R.drawable.ic_brand_cred
    return BRANDS.entries
        .filter { (k, _) -> k != "cred" && n.containsWord(k) }
        .maxByOrNull { (k, _) -> k.length }?.value
}

// full 233-key map, word-boundary match, longest wins.
private val BRANDS = mapOf(
"1mg" to R.drawable.ic_brand_1mg,
"5paisa" to R.drawable.ic_brand_5paisa,
"99acres" to R.drawable.ic_brand_99acres,
"abhibus" to R.drawable.ic_brand_abhibus,
"acko" to R.drawable.ic_brand_acko,
"adani electricity" to R.drawable.ic_brand_adani_electricity,
"adcb" to R.drawable.ic_brand_adcb,
"air india" to R.drawable.ic_brand_air_india,
"airtel" to R.drawable.ic_brand_airtel,
"ajio" to R.drawable.ic_brand_ajio,
"alinma" to R.drawable.ic_brand_alinma_bank,
"amazon" to R.drawable.ic_brand_amazon,
"amazon pay" to R.drawable.ic_brand_amazon_pay,
"amazon prime" to R.drawable.ic_brand_amazon_prime,
"american express" to R.drawable.ic_brand_amex,
"amex" to R.drawable.ic_brand_amex,
"angel one" to R.drawable.ic_brand_angel_one,
"anytime fitness" to R.drawable.ic_brand_anytime_fitness,
"apollo pharmacy" to R.drawable.ic_brand_apollo_pharmacy,
"apple music" to R.drawable.ic_brand_apple_music,
"au bank" to R.drawable.ic_brand_au_bank,
"au small finance" to R.drawable.ic_brand_au_bank,
"axis bank" to R.drawable.ic_brand_axis_bank,
"bajaj allianz" to R.drawable.ic_brand_bajaj_allianz,
"bancolombia" to R.drawable.ic_brand_bancolombia,
"bandhan bank" to R.drawable.ic_brand_bandhan_bank,
"bank of baroda" to R.drawable.ic_brand_bank_of_baroda,
"bank of india" to R.drawable.ic_brand_bank_of_india,
"barbeque nation" to R.drawable.ic_brand_barbeque_nation,
"bigbasket" to R.drawable.ic_brand_bigbasket,
"blinkit" to R.drawable.ic_brand_blinkit,
"blu smart" to R.drawable.ic_brand_blu_smart,
"bookmyshow" to R.drawable.ic_brand_bookmyshow,
"bounce" to R.drawable.ic_brand_bounce,
"bses" to R.drawable.ic_brand_bses,
"bsnl" to R.drawable.ic_brand_bsnl,
"burger king" to R.drawable.ic_brand_burger_king,
"byjus" to R.drawable.ic_brand_byjus,
"cafe coffee day" to R.drawable.ic_brand_cafe_coffee_day,
"canara bank" to R.drawable.ic_brand_canara_bank,
"central bank of india" to R.drawable.ic_brand_central_bank_of_india,
"charles schwab" to R.drawable.ic_brand_charles_schwab,
"cib egypt" to R.drawable.ic_brand_cib_egypt,
"cinepolis" to R.drawable.ic_brand_cinepolis,
"citi bank" to R.drawable.ic_brand_citi_bank,
"citibank" to R.drawable.ic_brand_citi_bank,
"citizens bank" to R.drawable.ic_brand_citizens_bank,
"city union bank" to R.drawable.ic_brand_city_union_bank,
"cleartrip" to R.drawable.ic_brand_cleartrip,
"coin" to R.drawable.ic_brand_coin,
"commercial bank of ethiopia" to R.drawable.ic_brand_cbe_bank,
"coursera" to R.drawable.ic_brand_coursera,
"cred" to R.drawable.ic_brand_cred,
"cultfit" to R.drawable.ic_brand_cultfit,
"curefit" to R.drawable.ic_brand_curefit,
"dbs" to R.drawable.ic_brand_dbs_bank,
"dbs bank" to R.drawable.ic_brand_dbs_bank,
"dialog axiata" to R.drawable.ic_brand_dialog,
"discover" to R.drawable.ic_brand_discover,
"dish tv" to R.drawable.ic_brand_dish_tv,
"dmart" to R.drawable.ic_brand_dmart,
"dominos" to R.drawable.ic_brand_dominos,
"dream11" to R.drawable.ic_brand_dream11,
"dunzo" to R.drawable.ic_brand_dunzo,
"economic times" to R.drawable.ic_brand_economic_times,
"emirates nbd" to R.drawable.ic_brand_emirates_nbd,
"equitas" to R.drawable.ic_brand_equitas_bank,
"eros now" to R.drawable.ic_brand_eros_now,
"etmoney" to R.drawable.ic_brand_etmoney,
"everest bank" to R.drawable.ic_brand_everest_bank,
"fab bank" to R.drawable.ic_brand_fab_bank,
"federal bank" to R.drawable.ic_brand_federal_bank,
"first abu dhabi" to R.drawable.ic_brand_fab_bank,
"firstcry" to R.drawable.ic_brand_firstcry,
"fitternity" to R.drawable.ic_brand_fitternity,
"flipkart" to R.drawable.ic_brand_flipkart,
"freecharge" to R.drawable.ic_brand_freecharge,
"gaana" to R.drawable.ic_brand_gaana,
"glomark" to R.drawable.ic_brand_glomark,
"goibibo" to R.drawable.ic_brand_goibibo,
"golds gym" to R.drawable.ic_brand_golds_gym,
"great learning" to R.drawable.ic_brand_great_learning,
"grofers" to R.drawable.ic_brand_grofers,
"groww" to R.drawable.ic_brand_groww,
"haldirams" to R.drawable.ic_brand_haldirams,
"hathway" to R.drawable.ic_brand_hathway,
"hdfc bank" to R.drawable.ic_brand_hdfc_bank,
"hdfc life" to R.drawable.ic_brand_hdfc_life,
"healthifyme" to R.drawable.ic_brand_healthifyme,
"healthkart" to R.drawable.ic_brand_healthkart,
"hindustan times" to R.drawable.ic_brand_hindustan_times,
"housejoy" to R.drawable.ic_brand_housejoy,
"housingcom" to R.drawable.ic_brand_housingcom,
"hsbc" to R.drawable.ic_brand_hsbc_bank,
"huntington" to R.drawable.ic_brand_huntington_bank,
"huntington bank" to R.drawable.ic_brand_huntington_bank,
"icici bank" to R.drawable.ic_brand_icici_bank,
"icici prudential" to R.drawable.ic_brand_icici_prudential,
"idfc first bank" to R.drawable.ic_brand_idfc_first_bank,
"ind money" to R.drawable.ic_brand_ind_money,
"india post payments bank" to R.drawable.ic_brand_ippb,
"indian bank" to R.drawable.ic_brand_indian_bank,
"indian express" to R.drawable.ic_brand_indian_express,
"indian overseas bank" to R.drawable.ic_brand_indian_overseas_bank,
"indigo" to R.drawable.ic_brand_indigo,
"indusind bank" to R.drawable.ic_brand_indusind_bank,
"inox" to R.drawable.ic_brand_inox,
"iob" to R.drawable.ic_brand_indian_overseas_bank,
"ippb" to R.drawable.ic_brand_ippb,
"irctc" to R.drawable.ic_brand_irctc,
"ixigo" to R.drawable.ic_brand_ixigo,
"jio" to R.drawable.ic_brand_jio,
"jiomart" to R.drawable.ic_brand_jiomart,
"jiosaavn" to R.drawable.ic_brand_jiosaavn,
"jupiter" to R.drawable.ic_brand_jupiter_bank,
"juspay" to R.drawable.ic_brand_juspay,
"karnataka bank" to R.drawable.ic_brand_karnataka_bank,
"keells" to R.drawable.ic_brand_keells,
"kerala gramin bank" to R.drawable.ic_brand_kerala_gramin_bank,
"kfc" to R.drawable.ic_brand_kfc,
"kotak mahindra bank" to R.drawable.ic_brand_kotak_mahindra_bank,
"kuvera" to R.drawable.ic_brand_kuvera,
"laxmi sunrise" to R.drawable.ic_brand_laxmi_sunrise_bank,
"lazypay" to R.drawable.ic_brand_lazypay,
"lic" to R.drawable.ic_brand_lic,
"liv bank" to R.drawable.ic_brand_liv_bank,
"lumbini bikash bank" to R.drawable.ic_brand_lumbini_bikash_bank,
"lybrate" to R.drawable.ic_brand_lybrate,
"m-pesa" to R.drawable.ic_brand_mpesa,
"machchhapuchchhre bank" to R.drawable.ic_brand_machhapuchchhre_bank,
"magicbricks" to R.drawable.ic_brand_magicbricks,
"makemytrip" to R.drawable.ic_brand_makemytrip,
"mashreq" to R.drawable.ic_brand_mashreq_bank,
"max life" to R.drawable.ic_brand_max_life,
"mcdonalds" to R.drawable.ic_brand_mcdonalds,
"medlife" to R.drawable.ic_brand_medlife,
"meesho" to R.drawable.ic_brand_meesho,
"microsoft teams" to R.drawable.ic_brand_microsoft_teams,
"mobikwik" to R.drawable.ic_brand_mobikwik,
"mobitel" to R.drawable.ic_brand_mobitel,
"mpesa" to R.drawable.ic_brand_mpesa,
"mpl" to R.drawable.ic_brand_mpl,
"mtnl" to R.drawable.ic_brand_mtnl,
"mx player" to R.drawable.ic_brand_mx_player,
"myntra" to R.drawable.ic_brand_myntra,
"nabil bank" to R.drawable.ic_brand_nmb_bank,
"navy federal" to R.drawable.ic_brand_navy_federal,
"nepal bank" to R.drawable.ic_brand_nepal_bank,
"nepal bank limited" to R.drawable.ic_brand_nepal_bank,
"nepal sbi bank" to R.drawable.ic_brand_nepal_sbi_bank,
"netflix" to R.drawable.ic_brand_netflix,
"netmeds" to R.drawable.ic_brand_netmeds,
"nmb bank" to R.drawable.ic_brand_nmb_bank,
"nobroker" to R.drawable.ic_brand_nobroker,
"nykaa" to R.drawable.ic_brand_nykaa,
"ola" to R.drawable.ic_brand_ola,
"ola electric" to R.drawable.ic_brand_ola_electric,
"paytm" to R.drawable.ic_brand_paytm,
"paytm first games" to R.drawable.ic_brand_paytm_first_games,
"paytm insider" to R.drawable.ic_brand_paytm_insider,
"paytm money" to R.drawable.ic_brand_paytm_money,
"pepperfry" to R.drawable.ic_brand_pepperfry,
"pharmeasy" to R.drawable.ic_brand_pharmeasy,
"phonepe" to R.drawable.ic_brand_phonepe,
"pickme" to R.drawable.ic_brand_pickme,
"pizza hut" to R.drawable.ic_brand_pizza_hut,
"policybazaar" to R.drawable.ic_brand_policybazaar,
"practo" to R.drawable.ic_brand_practo,
"priorbank" to R.drawable.ic_brand_priorbank,
"punjab national bank" to R.drawable.ic_brand_punjab_national_bank,
"pvr" to R.drawable.ic_brand_pvr,
"rapido" to R.drawable.ic_brand_rapido,
"rbl bank" to R.drawable.ic_brand_rbl_bank,
"redbus" to R.drawable.ic_brand_redbus,
"saraswat bank" to R.drawable.ic_brand_saraswat_bank,
"sbi" to R.drawable.ic_brand_sbi,
"sbi life" to R.drawable.ic_brand_sbi_life,
"schwab" to R.drawable.ic_brand_charles_schwab,
"selcom" to R.drawable.ic_brand_selcom_pesa,
"shopclues" to R.drawable.ic_brand_shopclues,
"siddhartha bank" to R.drawable.ic_brand_siddhartha_bank,
"simpl" to R.drawable.ic_brand_simpl,
"simplilearn" to R.drawable.ic_brand_simplilearn,
"slack" to R.drawable.ic_brand_slack,
"slice" to R.drawable.ic_brand_slice,
"slt" to R.drawable.ic_brand_slt,
"smallcase" to R.drawable.ic_brand_smallcase,
"snapdeal" to R.drawable.ic_brand_snapdeal,
"sony liv" to R.drawable.ic_brand_sony_liv,
"south indian bank" to R.drawable.ic_brand_south_indian_bank,
"spicejet" to R.drawable.ic_brand_spicejet,
"spotify" to R.drawable.ic_brand_spotify,
"standard chartered" to R.drawable.ic_brand_standard_chartered,
"standard chartered bank nepal" to R.drawable.ic_brand_standard_chartered,
"starbucks" to R.drawable.ic_brand_starbucks,
"sun direct" to R.drawable.ic_brand_sun_direct,
"swiggy" to R.drawable.ic_brand_swiggy,
"tata aia" to R.drawable.ic_brand_tata_aia,
"tata power" to R.drawable.ic_brand_tata_power,
"tata sky" to R.drawable.ic_brand_tata_sky,
"the hindu" to R.drawable.ic_brand_the_hindu,
"the times of india" to R.drawable.ic_brand_the_times_of_india,
"tigo pesa" to R.drawable.ic_brand_tigo_pesa,
"tikona" to R.drawable.ic_brand_tikona,
"timespoints" to R.drawable.ic_brand_timespoints,
"toppr" to R.drawable.ic_brand_toppr,
"truemeds" to R.drawable.ic_brand_truemeds,
"uber" to R.drawable.ic_brand_uber,
"udacity" to R.drawable.ic_brand_udacity,
"udemy" to R.drawable.ic_brand_udemy,
"unacademy" to R.drawable.ic_brand_unacademy,
"union bank" to R.drawable.ic_brand_union_bank,
"upgrad" to R.drawable.ic_brand_upgrad,
"upstox" to R.drawable.ic_brand_upstox,
"urban company" to R.drawable.ic_brand_urban_company,
"urban ladder" to R.drawable.ic_brand_urban_ladder,
"vedantu" to R.drawable.ic_brand_vedantu,
"vistara" to R.drawable.ic_brand_vistara,
"vodafone" to R.drawable.ic_brand_vodafone,
"vodafone idea" to R.drawable.ic_brand_vodafone_idea,
"vogo" to R.drawable.ic_brand_vogo,
"voot" to R.drawable.ic_brand_voot,
"whitehat jr" to R.drawable.ic_brand_whitehat_jr,
"wynk" to R.drawable.ic_brand_wynk,
"yatra" to R.drawable.ic_brand_yatra,
"yes bank" to R.drawable.ic_brand_yes_bank,
"youtube" to R.drawable.ic_brand_youtube,
"yulu" to R.drawable.ic_brand_yulu,
"zee5" to R.drawable.ic_brand_zee5,
"zepto" to R.drawable.ic_brand_zepto,
"zerodha" to R.drawable.ic_brand_zerodha,
"zomato" to R.drawable.ic_brand_zomato,
"zoom" to R.drawable.ic_brand_zoom,
)

/** Compose preview check: word-boundary matcher. */
internal fun brandMatchDebug(merchant: String, key: String): Boolean = merchant.lowercase().containsWord(key)

@Composable
fun BrandAvatarPreview() {
    BrandAvatar("Starbucks", "☕")
}
