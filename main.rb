# -*- coding: utf-8 -*-
require 'win32ole'  
#require 'spreadsheet' old function.
require 'writeexcel'




#客戶每日交易明細
def CustomDailyTransactionDetail(connection,current_pid,current_cid,current_date)
	#取符合條件的產品
	recordset_product = WIN32OLE.new('ADODB.Recordset')
 	if(current_pid.to_i()>=100)
    	sql = "select * from product where cint(PID)>=#{current_pid[1]+'0'} and cint(PID)<=#{current_pid[1]+'9'} order by CLng(PID);"
	else
		sql = "select * from product where PID='#{current_pid}';"
	end
	recordset_product.Open(sql, connection)

	#取符合條件的使用者資料
	recordset_custom = WIN32OLE.new('ADODB.Recordset')
	sql = "select top 1 * from custom where CID='#{current_cid}';"
	recordset_custom.Open(sql, connection)

	#取符合條件的交易
	recordset_order = WIN32OLE.new('ADODB.Recordset')
	if(current_pid.to_i()>=100)
		sql = "select * from [order] where cint(PID)>=#{current_pid[1]+'0'} and cint(PID)<=#{current_pid[1]+'9'} and CID='#{current_cid}' and CurrentDate='#{current_date}' order by group,PID;"
	else
		sql = "select * from [order] where PID='#{current_pid}' and CID='#{current_cid}' and CurrentDate='#{current_date}' order by group;"
	end
	recordset_order.Open(sql, connection)

	#取符合條件且最接近想搜尋的日期的一筆的價格
	recordset_price = WIN32OLE.new('ADODB.Recordset')
	if(current_pid.to_i()>=100)
		sql = "select * from price where cint(PID)>=#{current_pid[1]+'0'} and cint(PID)<=#{current_pid[1]+'9'} and CID='#{current_cid}' and CurrentDate<='#{current_date}' order by CurrentDate desc;"
	else
		sql = "select * from price where PID='#{current_pid}' and CID='#{current_cid}' and CurrentDate<='#{current_date}' order by CurrentDate desc;"
	end
	recordset_price.Open(sql, connection)






	#預存出所有會需要列出的資料
	#product
	data_product = recordset_product.GetRows.transpose
	if(current_pid.to_i()>=100)
		full_pname=data_product.first.last.sub(/_.*/,'_全')
	else
		full_pname=data_product.first.last
	end
	pname=data_product.first.last.sub(/_.*/,'')


	#custom
	data_custom = recordset_custom.GetRows.transpose
	hash_custom=Hash.new
	data_custom.each(){|cid,cname,ctype,address,opendate,bankid,proportion,bonustarget,phone1,phone2,phone3,phone4,phone5,phone6,note|
 		hash_custom["cid"]=cid
		hash_custom["cname"]=cname
		hash_custom["ctype"]=ctype
		hash_custom["address"]=address
		hash_custom["opendate"]=opendate
		hash_custom["bankid"]=bankid
		hash_custom["proportion"]=proportion
		hash_custom["bonustarget"]=bonustarget
		hash_custom["phone1"]=phone1
		hash_custom["phone2"]=phone2
		hash_custom["phone3"]=phone3
		hash_custom["phone4"]=phone4
		hash_custom["phone5"]=phone5
		hash_custom["phone6"]=phone6
		hash_custom["note"]=note
	}


	#price
	data_price = recordset_price.GetRows.transpose
	newcurrentdate=data_price.first.at(3)	#get newest currentdate from data array
	data_price.delete_if{|swiftcode,cid,pid,currentdate,currentprice,winningprice,upset|
		currentdate!=newcurrentdate
	}
	current_price=Hash[
		data_price.collect(){|swiftcode,cid,pid,currentdate,currentprice,winningprice,upset|
			[pid,currentprice]
		}
	]
	winning_price=Hash[
		data_price.collect(){|swiftcode,cid,pid,currentdate,currentprice,winningprice,upset|
			[pid,winningprice]
		}
	]

	#order
	data_order = recordset_order.GetRows.transpose



	#取得交易日期的年月日
	year=current_date.sub(/\/.*/,'')
	month=current_date.sub(year+'/','').sub(/\/.*/,'')
	day=current_date.sub(/.*\//,'')
	free_current_date=current_date.gsub(/\//,'')


	
	#Write the file
	FileUtils.mkdir_p("report/#{year}/#{month}/")
	# Create a new Excel Workbook
	book = WriteExcel.new("report/#{year}/#{month}/#{free_current_date}_#{hash_custom['cname']}_#{full_pname}_客戶每日交易明細.xls")
	# Add worksheet(s)
	sheet  = book.add_worksheet



	#Write a number and formula using A1 notation, and add row
	#列舉產品名
	pnamelist=Array.new
	data_product.each(){|pid,pname| 
		newpname=pname.sub(/.*_/,'') 
		pnamelist+=[newpname]+[newpname+'中']
	}
	row = ['類別']+pnamelist
	sheet.write('A1', row)
	

	#列舉數量，並計算金額
	currentcountlist=Hash.new(0)
	winningcountlist=Hash.new(0)
	data_order.each(){|swiftcode,cid,pid,currentdate,currentcount,winningcount,addmoney,bonusmoney,note,group| 
		currentcountlist[pid]+=currentcount.to_f()
		winningcountlist[pid]+=winningcount.to_f()
	}
	countlist=Array.new
	paylist=Array.new
	currentcountlist.each(){|key,value|
		countlist+=[currentcountlist[key]]+[winningcountlist[key]]
		paylist+=[currentcountlist[key]*current_price[key].to_f()]+[winningcountlist[key]*winning_price[key].to_f()]
	}
	row = ['牌支']+countlist	
	sheet.write('A2', row)
	row = ['金額']+paylist
	sheet.write('A3', row)


	#計算應收、漲價、佔成
	#row = ['應收']+[paylist.sum.round(4)]+['','','','']+['漲價']+[data_order.at(0).at(6)]+['']+['佔成']+[data_order.at(0).at(7)]	#get newest addmoney and bounsmoney from data array
	row = ['應收']
	sheet.write('A4',row)
	row = [paylist.sum.round(4)]
	sheet.merge_range('B4:F4',row,book.add_format)
	row= ['漲價']
	sheet.write('G4',row)
	row=[data_order.at(0).at(6)]
	sheet.merge_range('H4:I4',row,book.add_format)
	row=['佔成']+[data_order.at(0).at(7)]
	sheet.write('J4',row)


	#顯示日期、產品類別、姓名
	row = [current_date]
	sheet.write('A5', row)
	format = book.add_format
	format.set_format_properties(:bg_color => 'gray',:pattern  => 1)
	row = [pname]
	sheet.write('B5', row, format)
	row = [hash_custom['cname']]
	sheet.merge_range('C5:K5', row, book.add_format)

	#列舉產品名
	row = ['單號']+pnamelist
	sheet.write('A6', row)


	#為每一筆交易列舉
	currentcountlist=Hash.new(0)
	winningcountlist=Hash.new(0)
	oldgroup=-1
	data_order.each(){|swiftcode,cid,pid,currentdate,currentcount,winningcount,addmoney,bonusmoney,note,group| 
		if oldgroup==-1
			oldgroup=group
		elsif oldgroup!=group
			oldgroup=group

			countlist=Array.new
			currentcountlist.each(){|key,value|
				countlist+=[currentcountlist[key]]+[winningcountlist[key]]
			}
			row = ["%02d"%oldgroup]+countlist
			sheet.write('A'+(6+oldgroup).to_s(), row)
			
			currentcountlist=Hash.new(0)
			winningcountlist=Hash.new(0)
		end

		currentcountlist[pid]+=currentcount.to_f()
		winningcountlist[pid]+=winningcount.to_f()		
	}
	oldgroup=oldgroup.to_i()+1

	countlist=Array.new
	currentcountlist.each(){|key,value|
		countlist+=[currentcountlist[key]]+[winningcountlist[key]]
	}
	row = ["%02d"%oldgroup]+countlist	
	sheet.write('A'+(6+oldgroup).to_s(), row)



	#close recordset
	recordset_product.close
	recordset_custom.close
	recordset_order.close
	recordset_price.close


	# write to file
	book.close

	#End
	p "#{free_current_date}_#{hash_custom['cname']}_#{full_pname}_客戶每日交易明細.xls 已輸出"

end






#每日交易加總表
def DailyTransactionCounting(connection,current_pid,current_date)
	#取符合條件的產品
	recordset_product = WIN32OLE.new('ADODB.Recordset')
 	if(current_pid.to_i()>=100)
    	sql = "select * from product where cint(PID)>=#{current_pid[1]+'0'} and cint(PID)<=#{current_pid[1]+'9'} order by CLng(PID);"
	else
		sql = "select * from product where PID='#{current_pid}';"
	end
	recordset_product.Open(sql, connection)

	#取符合條件的使用者資料
	recordset_custom = WIN32OLE.new('ADODB.Recordset')
	sql = "select * from custom;"
	recordset_custom.Open(sql, connection)

	#取符合條件的交易
	recordset_order = WIN32OLE.new('ADODB.Recordset')
	if(current_pid.to_i()>=100)
		sql = "select * from [order] where cint(PID)>=#{current_pid[1]+'0'} and cint(PID)<=#{current_pid[1]+'9'} and CurrentDate='#{current_date}' order by group,PID;"
	else
		sql = "select * from [order] where PID='#{current_pid}' and CurrentDate='#{current_date}' order by group;"
	end
	recordset_order.Open(sql, connection)

	#取符合條件且最接近想搜尋的日期的一筆的價格
	recordset_price = WIN32OLE.new('ADODB.Recordset')
	if(current_pid.to_i()>=100)
		sql = "select * from price where cint(PID)>=#{current_pid[1]+'0'} and cint(PID)<=#{current_pid[1]+'9'} and CurrentDate<='#{current_date}' order by CurrentDate desc;"
	else
		sql = "select * from price where PID='#{current_pid}' and CurrentDate<='#{current_date}' order by CurrentDate desc;"
	end
	recordset_price.Open(sql, connection)






	#預存出所有會需要列出的資料
	#product
	data_product = recordset_product.GetRows.transpose
	if(current_pid.to_i()>=100)
		full_pname=data_product.first.last.sub(/_.*/,'_全')
	else
		full_pname=data_product.first.last
	end
	pname=data_product.first.last.sub(/_.*/,'')


	#custom
	data_custom = recordset_custom.GetRows.transpose


	#price
	data_price = recordset_price.GetRows.transpose
	newcurrentdate=data_price.first.at(3)	#get newest currentdate from data array
	data_price.delete_if{|swiftcode,cid,pid,currentdate,currentprice,winningprice,upset|
		currentdate!=newcurrentdate
	}
	current_price=Hash[
		data_price.collect(){|swiftcode,cid,pid,currentdate,currentprice,winningprice,upset|
			[pid,currentprice]
		}
	]
	winning_price=Hash[
		data_price.collect(){|swiftcode,cid,pid,currentdate,currentprice,winningprice,upset|
			[pid,winningprice]
		}
	]

	#order
	data_order = recordset_order.GetRows.transpose



	#取得交易日期的年月日
	year=current_date.sub(/\/.*/,'')
	month=current_date.sub(year+'/','').sub(/\/.*/,'')
	day=current_date.sub(/.*\//,'')
	free_current_date=current_date.gsub(/\//,'')


	

	#Write the file
	FileUtils.mkdir_p("report/#{year}/#{month}/")
	# Create a new Excel Workbook
	book = WriteExcel.new("report/#{year}/#{month}/#{free_current_date}_#{full_pname}_每日交易加總表.xls")
	# Add worksheet(s)
	sheet  = book.add_worksheet



	#Create the rows to be inserted, and add row
	if(current_pid.to_i()==-1)
		row = [current_date]+['日總計']
	else
		row = [current_date]+[pname,'小計']
	end
	sheet.write('A1', row)


	#列舉產品名
	pnamelist=Array.new
	data_product.each(){|pid,pname| 
		newpname=pname.sub(/.*_/,'') 
		pnamelist+=[newpname]+[newpname+'中']
	}
	row = ['類別']+pnamelist+['其它','其它中','應收(含水)','應收(扣水)','水','漲價']
	sheet.write('A2', row)


	#計算出、入、留
	outcurrentcountlist=Hash.new(0)
	outwinningcountlist=Hash.new(0)
	incurrentcountlist=Hash.new(0)
	inwinningcountlist=Hash.new(0)
	customlist=Hash.new
	data_order.each(){|swiftcode,cid,pid,currentdate,currentcount,winningcount,addmoney,bonusmoney,note,group| 
		if(currentcount.to_f()>=0)
			outcurrentcountlist[pid]+=currentcount.to_f()
			outwinningcountlist[pid]+=winningcount.to_f()
			
			#若客戶的ID HASH尚未建立，則為每個客戶ID建置HASH，以供分別儲存他們的交易及中獎數量
			if(customlist[cid]==nil)
				customlist[cid]={'outcurrentcountlist'=>Hash.new(0),'outwinningcountlist'=>Hash.new(0),'incurrentcountlist'=>Hash.new(0),'inwinningcountlist'=>Hash.new(0)}
			end
			customlist[cid]['outcurrentcountlist'][pid]+=currentcount.to_f()
			customlist[cid]['outwinningcountlist'][pid]+=winningcount.to_f()
		else
			incurrentcountlist[pid]+=currentcount.to_f()
			inwinningcountlist[pid]+=winningcount.to_f()

			#若客戶的ID HASH尚未建立，則為每個客戶ID建置HASH，以供分別儲存他們的交易及中獎數量
			if(customlist[cid]==nil)
				customlist[cid]={'outcurrentcountlist'=>Hash.new(0),'outwinningcountlist'=>Hash.new(0),'incurrentcountlist'=>Hash.new(0),'inwinningcountlist'=>Hash.new(0)}
			end
			customlist[cid]['incurrentcountlist'][pid]+=currentcount.to_f()
			customlist[cid]['inwinningcountlist'][pid]+=winningcount.to_f()
		end
	}

	#計算誤差
	outpaylist=Array.new
	inpaylist=Array.new
	outcurrentcountlist.each(){|key,value|
		outpaylist+=[outcurrentcountlist[key]*current_price[key].to_f()]+[outwinningcountlist[key]*winning_price[key].to_f()]
		inpaylist+=[incurrentcountlist[key]*current_price[key].to_f()]+[inwinningcountlist[key]*winning_price[key].to_f()]
	}
	row = ['出']+outpaylist+[0,0,0,0,0,0]
	sheet.write('A3', row)
	row = ['入']+inpaylist+[0,0,0,0,0,0]
	sheet.write('A4', row)
	row = ['留']+[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
	sheet.write('A5', row)
	row = ['誤差']
	(pnamelist.count+6).times(){|i|
		col=('B'.ord+i).chr
		row+=["=#{col}4-#{col}3-#{col}5"]
	}
	sheet.write('A6', row)

	#插入空白行
	row=['']
	sheet.write('A7', row)	

	#顯示出的客戶詳細清單
	row = ['出']+pnamelist+['其它','其它中','應收(含水)','應收(扣水)','水','漲價']
	sheet.write('A8', row)

	rowindex=0
	data_custom.each(){|cid,cname,ctype,address,opendate,bankid,proportion,bonustarget,phone1,phone2,phone3,phone4,phone5,phone6,note|
		row = [cname]
		if(customlist[cid]==nil)
			row+=[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
		else
			outcurrentcountlist.each(){|key,value|
				row+=[customlist[cid]['outcurrentcountlist'][key]*current_price[key].to_f()]+[customlist[cid]['outwinningcountlist'][key]*winning_price[key].to_f()]
			}
			row+=[0,0,0,0,0,0]
		end
		sheet.write('A'+(9+rowindex).to_s(), row)
		rowindex+=1
	}
	

	#顯示留底的客戶詳細清單
	row = ['留底']+[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
	sheet.write('A'+(9+rowindex).to_s(), row)
	rowindex+=1


	#顯示入的客戶詳細清單
	row = ['入']+pnamelist+['其它','其它中','應收(含水)','應收(扣水)','水','漲價']
	sheet.write('A'+(9+rowindex).to_s(), row)
	rowindex+=1

	data_custom.each(){|cid,cname,ctype,address,opendate,bankid,proportion,bonustarget,phone1,phone2,phone3,phone4,phone5,phone6,note|
		row = [cname]
		if(customlist[cid]==nil)
			row+=[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
		else
			outcurrentcountlist.each(){|key,value|
				row+=[customlist[cid]['incurrentcountlist'][key]*current_price[key].to_f()]+[customlist[cid]['inwinningcountlist'][key]*winning_price[key].to_f()]
			}
			row+=[0,0,0,0,0,0]
		end
		sheet.write('A'+(9+rowindex).to_s(), row)
		rowindex+=1
	}


	#close recordset
	recordset_product.close
	recordset_custom.close
	recordset_order.close
	recordset_price.close


	# write to file
	book.close


	#End
	p "#{free_current_date}_#{full_pname}_每日交易加總表.xls 已輸出"

end






@connection = WIN32OLE.new('ADODB.Connection')
@connection.Open('Provider=Microsoft.ACE.OLEDB.12.0;Data Source=main.mdb')



#CustomDailyTransactionDetail(@connection,'100','1','2016/01/11')
DailyTransactionCounting(@connection,'100','2016/01/11')