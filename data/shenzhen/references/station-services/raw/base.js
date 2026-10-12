									window.onload = function(){
    document.documentElement.style.fontSize = document.documentElement.clientWidth/(12.8) +'px';
}



$(document).ready(function(){	
	
	//站点查询的
//	$('.cTitle').eq(5).html('公交换乘信息');
//	$('.conten_boy').eq(0).children('.left').remove();
//	var img_src = $('.conten_boy>.left>img').attr('src');
//	var img_ind = img_src.indexOf('.png');
//	var img_b = img_src.substr(0,img_ind);
//	if(img_src != ""){$('.conten_boy>.left>img').wrap('<a href="'+img_b+'_b.png" target="_blank"></a>');}
	
	$('.Operationtext.ibx .xz').html('');
	$.each(xlurlarr, function(i,v) {
		$('.Operationtext.ibx .xz').append(
			'<a href="javascript:;" tag="'+v.code+'" date="'+v.img+'">'+
				'<img src="images/b'+v.img+'.png" align="absmiddle" style="margin-top:-4px"><br>'+v.name+
			'</a>'
		);
	});
	
	//站点信息标题线路
//	var xlbt =$.trim($('.ibx .txtLinetit').text());
//	var getxl ='';
//	if(xlbt=="罗宝线"){
//		getxl='1';
//	}
//	else if(xlbt=="蛇口线"){
//		getxl='2';
//	}
//	else if(xlbt=="龙岗线"){
//		getxl='3';
//	}
//	else if(xlbt=="龙华线"){
//		getxl='4';
//	}
//	else if(xlbt=="环中线"){
//		getxl='5';
//	}
//	else if(xlbt=="西丽线"){
//		getxl='7';
//	}
//	else if(xlbt=="梅林线"){
//		getxl='9';
//	}
//	else if(xlbt=="机场线"){
//		getxl='11';
//	}
//	$.each(zdurl,function(i,v){
//		if(zdurl[i].line==getxl){
//			$.each(zdurl[i].zdList, function(ii,vv) {
//				$('.zd_nav tr').append(
//					'<td><a href="javascript:;" tag="'+vv.tag+'">'+vv.name+'</a></td>'
//				);
//			});
//		}
//	});
	$('.zd_nav tr').html('');
//	$.each(zdurl,function(i,v){
//		if(zdurl[i].line==1){
			$.each(zdurl[0].zdList, function(ii,vv) {
				$('.zd_nav tr').append(
					'<td><a href="javascript:;" tag="'+vv.code+'">'+vv.name+'</a></td>'
				);
			});
//		}
//	});
	
	//点击线路
	$('.xz a').on('click',function(){
		$(this).addClass('hover').siblings().removeClass('hover');
		zdcode=$(this).attr('tag');
		ajaxXL();
		var index=$(this).attr('date');
		$('.zd_nav tr').html('');
		$.each(zdurl,function(i,v){
			if(zdurl[i].line==index){
				$.each(zdurl[i].zdList, function(ii,vv) {
					$('.zd_nav tr').append(
						'<td><a href="javascript:;" tag="'+vv.code+'">'+vv.name+'</a></td>'
					);
				});
			}
		});
		$('.ibx .txtLinetit').html('<img style="margin-top: -3px;" src="images/b'+index+'.png" />'+xlurlarr[$(this).index()].name);
		$('.zd_nav tr td a').eq(0).addClass('on');
	});
	//点击站点
	$(document).on('click','.zd_nav tr td a',function(){
		$(this).addClass('on').parents('td').siblings().find('a').removeClass('on');
//		$(this).parents('tr').siblings().find('td a').removeClass('on');
		zdcode=$(this).attr('tag');
		ajaxXL();
	});
	
//	$('.Operationtext.ibx .xz a').each(function(i,v){
//		var thistxt = $.trim($(this).text());
//		if(xlbt==thistxt){
//			$(this).addClass('hover');
//		}
//	});
	$('.Operationtext.ibx .xz a').eq(0).addClass('hover');
	
//	var zd =$.trim($('.conten_bt').text());
//	zd = zd.toLowerCase();
//	$('.zd_nav tr td a').each(function(i,v){
//		var thistxt = $.trim($(this).text());
//		thistxt = thistxt.toLowerCase();
//		if(thistxt==zd){
//			$(this).addClass('on');
//		}
//	});
	$('.zd_nav tr td a').eq(0).addClass('on');
	
	//装载数据	
	function searchResultHtml(date) {		
	var text = "";
	text += '<div class="conten_bt">'+date.siteName+'</div>' +
		'            <!-- 上半部分 -->' +
		'            <div class="conten_boy">' +
		'            	<div class="right">            		' +
		'            	<!-- 站点介绍 -->' +
	    '        		<div class="cBox1">' +
	    '        			<div class="cTitle">站点介绍</div>' +
	    '        			<div class="cText">'+date.siteIntroduce+'</div>' +	            			
	    '        		</div>' +
		'            		<!-- 运营时刻表(工作日) -->' +
		'            		<div class="cBox1">' +
		'            			<div class="cTitle">运营时刻表(工作日)</div>' +
		'            			<table class="yyskb">' +
		'            				<tr>'+
		'                                <td>行驶方向</td>'+
		'                                <td>首班车</td>'+
		'                                <td>末班车</td>'+
		'                                <td>所属线路</td>'+
		'                                <td>高峰间隔</td>'+
		'                                <td>平峰间隔</td>'+
		'                            </tr>';
									for (var i=0;i<date.workDay.length;i++) {
		text+='							<tr>' +
		'                                <td class="td1">'+date.workDay[i].xinshifangxiang+'</td>' +
		'                                <td class="td2">'+date.workDay[i].shoubanche+'</td>' +
		'                                <td class="td3">'+date.workDay[i].mobanche+'</td>' +
		'                                <td class="td1">'+date.workDay[i].suoshuluxian+'</td>' +
		'                                <td class="td2">'+date.workDay[i].gaofenjiange+'</td>' +
		'                                <td class="td3">'+date.workDay[i].pingjunjiange+'</td>' +
		'                            </tr>' +		
		'							<tr>' +
		'                                <td class="td1">'+date.workDay[i].xinshifangxiangxia+'</td>' +
		'                                <td class="td2">'+date.workDay[i].shoubanchexia+'</td>' +
		'                                <td class="td3">'+date.workDay[i].mobanchexia+'</td>' +
		'                                <td class="td1">'+date.workDay[i].suoshuluxian+'</td>' +
		'                                <td class="td2">'+date.workDay[i].gaofenjiange+'</td>' +
		'                                <td class="td3">'+date.workDay[i].pingjunjiange+'</td>' +
		'                            </tr>' ;
									}
		text+='            			</table>         			' +
		'            		</div>' +
		'            		<!-- 运营时刻表(休息日) -->' +
		'            		<div class="cBox1">' +
		'            			<div class="cTitle">运营时刻表(休息日)</div>' +
		'            			<table class="yyskb">' +
		'            				<tr>'+
		'                                <td>行驶方向</td>'+
		'                                <td>首班车</td>'+
		'                                <td>末班车</td>'+
		'                                <td>所属线路</td>'+
		'                                <td>高峰间隔</td>'+
		'                                <td>平峰间隔</td>'+
		'                            </tr>';
									for (var j=0;j<date.dayoff.length;j++) {
		text+='							<tr>' +
		'                                <td class="td1">'+date.dayoff[j].xinshifangxiang+'</td>' +
		'                                <td class="td2">'+date.dayoff[j].shoubanche+'</td>' +
		'                                <td class="td3">'+date.dayoff[j].mobanche+'</td>' +
		'                                <td class="td1">'+date.dayoff[j].suoshuluxian+'</td>' +
		'                                <td class="td2">'+date.dayoff[j].gaofenjiange+'</td>' +
		'                                <td class="td3">'+date.dayoff[j].pingjunjiange+'</td>' +
		'                            </tr>' +		
		'							<tr>' +
		'                                <td class="td1">'+date.dayoff[j].xinshifangxiangxia+'</td>' +
		'                                <td class="td2">'+date.dayoff[j].shoubanchexia+'</td>' +
		'                                <td class="td3">'+date.dayoff[j].mobanchexia+'</td>' +
		'                                <td class="td1">'+date.dayoff[j].suoshuluxian+'</td>' +
		'                                <td class="td2">'+date.dayoff[j].gaofenjiange+'</td>' +
		'                                <td class="td3">'+date.dayoff[j].pingjunjiange+'</td>' +
		'                            </tr>' ;
									}
		text+='            			</table>         			' +
		'            		</div>' +
		'            		<!-- 运营时刻表(节假日)以实际为准-->' +
		'            		<div class="cBox1">' +
		'            			<div class="cTitle">运营时刻表(节假日)以实际为准</div>' +
		'            			<table class="yyskb">' +
		'            				<tr>'+
		'                                <td>行驶方向</td>'+
		'                                <td>首班车</td>'+
		'                                <td>末班车</td>'+
		'                                <td>所属线路</td>'+
		'                                <td>高峰间隔</td>'+
		'                                <td>平峰间隔</td>'+
		'                            </tr>';
									for (var n=0;n<date.holidays.length;n++) {
		text+='							<tr>' +
		'                                <td class="td1">'+date.holidays[n].xinshifangxiang+'</td>' +
		'                                <td class="td2">'+date.holidays[n].shoubanche+'</td>' +
		'                                <td class="td3">'+date.holidays[n].mobanche+'</td>' +
		'                                <td class="td1">'+date.holidays[n].suoshuluxian+'</td>' +
		'                                <td class="td2">'+date.holidays[n].gaofenjiange+'</td>' +
		'                                <td class="td3">'+date.holidays[n].pingjunjiange+'</td>' +
		'                            </tr>' +		
		'							<tr>' +
		'                                <td class="td1">'+date.holidays[n].xinshifangxiangxia+'</td>' +
		'                                <td class="td2">'+date.holidays[n].shoubanchexia+'</td>' +
		'                                <td class="td3">'+date.holidays[n].mobanchexia+'</td>' +
		'                                <td class="td1">'+date.holidays[n].suoshuluxian+'</td>' +
		'                                <td class="td2">'+date.holidays[n].gaofenjiange+'</td>' +
		'                                <td class="td3">'+date.holidays[n].pingjunjiange+'</td>' +
		'                            </tr>' ;
									}
		text+='            			</table>         			' +
		'            		</div>' +
		'            	</div>' +
		'            </div>' +
		'            <!-- 下半部带图部分 -->' +
		'            <div class="conten_boy">' +
		'            	<div class="left">' +
		'            		<a href="images/'+date.siteCode+'_b.jpg" target="_blank"><img src="images/'+date.siteCode+'_s.jpg" /></a>' +
		'            	</div>' +
		'            	<div class="right">' +
		'            		<!-- 站点出口信息 -->' +
		'            		<div class="cBox1">' +
		'            			<div class="cTitle">站点出口信息</div>' +
		'            			<div class="cText">' +
		'            				<!-- 添加入口布局 -->' ;
									for (var o=0;o<date.outAndText.length;o++) {
		text+='            				<div class="cCrk">' +
		'            					<div class="ctitle">'+date.outAndText[o].outt+':</div>' +
		'            					<div class="txt">' +
										date.outAndText[o].textt +
		'            					</div>' +
		'            				</div>' ;
									}
		text+='            			</div>	            			' +
		'            		</div>' +
		'            		<!-- 公交换乘信息 -->' +
		'            		<div class="cBox1">' +
		'            			<div class="cTitle">公交换乘信息</div>' +
		'            			<div class="cText">' +
		'            				<!-- 添加入口布局 -->' ;
									for (var k=0;k<date.busInof.length;k++) {
										for(var m=0;m<date.busInof[k].busOutInfo.length;m++){
		text+='            				<div class="cCrk">' +
		'            					<div class="ctitle">'+date.busInof[k].chukou+':</div>' +
		'            					<div class="ctitle">公交站名： '+date.busInof[k].busOutInfo[m].busName+'</div>' +	            					
		'            					<div class="txt">'+date.busInof[k].busOutInfo[m].busInfo +'</div>' +																					
		'            					</div>' ;
										}
									}
		text+='            		</div>	            			' +
		'            		</div>' +
		'            	</div>' +
		'            </div>';
		
		$('.XL_wrap').html(text);
		var ifheight = $(".Operation").height();
		parent.$('.tabcon_news iframe').css({'height':ifheight});
	}
	
	var zdcode="0101";
	var get_url_val = parent.window.location.search.substring(1);
	if(get_url_val!=""&&get_url_val!=null){
		//处理8号线莲塘
		if(get_url_val=="0801"){
			get_url_val="0232";
		}
		
		zdcode=get_url_val;		
		
		var xlbt = zdcode;
		if(xlbt.indexOf('0')==0){
			xlbt=xlbt.substr(1,1);
			console.log(xlbt);
		}
		else{
			xlbt=xlbt.substr(0,2);
			console.log(xlbt);
		}
		$('.Operationtext.ibx .xz a').each(function(i,v){
			var thisdt = $(this).attr('date');
			if(xlbt==thisdt){
				$(this).addClass('hover').siblings().removeClass('hover');
				$('.ibx .txtLinetit').html('<img style="margin-top: -3px;" src="images/b'+xlbt+'.png" />'+xlurlarr[i].name);
			}
		});
		
		$('.zd_nav tr').html('');
		for (var i=0;i<zdurl.length;i++) {								
			if(zdurl[i].line==xlbt){
				$.each(zdurl[i].zdList, function(ii,vv) {
					$('.zd_nav tr').append(
						'<td><a href="javascript:;" tag="'+vv.code+'">'+vv.name+'</a></td>'
					);
				});
			}
		}
		
		$('.zd_nav tr td a').each(function(i,v){
			var thistag = $(this).attr('tag');
			if(thistag==zdcode){
				$(this).addClass('on').parents('td').siblings().find('a').removeClass('on');
			}
		});
	}
	function ajaxXL(){
		$.ajax({
			type:"post",
			url:"https://www.szmc.net/zdxx",
//			url:"http://10.33.1.220:8080/20190814ssh/Ticketing/StaticInfo.do",
			async:true,
			data:{StieCode:zdcode},
			success:function(res){
//				res=$.parseJSON(res);
				searchResultHtml(res);
			}
		});
	};
	ajaxXL();
})
						