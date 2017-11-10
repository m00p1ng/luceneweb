<!--
    Licensed to the Apache Software Foundation (ASF) under one or more
    contributor license agreements.  See the NOTICE file distributed with
    this work for additional information regarding copyright ownership.
    The ASF licenses this file to You under the Apache License, Version 2.0
    the "License"); you may not use this file except in compliance with
    the License.  You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
 -->
<%@page pageEncoding="UTF-8"%>
<%@ page import = "  java.util.Arrays, javax.servlet.*, javax.servlet.http.*, java.io.*, java.net.URLEncoder, java.net.URLDecoder, java.nio.file.Paths, org.apache.lucene.analysis.Analyzer, org.apache.lucene.analysis.TokenStream, org.apache.lucene.analysis.standard.StandardAnalyzer, org.apache.lucene.analysis.th.ThaiAnalyzer, org.apache.lucene.document.Document, org.apache.lucene.index.DirectoryReader, org.apache.lucene.index.IndexReader, org.apache.lucene.queryparser.classic.QueryParser, org.apache.lucene.queryparser.classic.ParseException, org.apache.lucene.search.IndexSearcher, org.apache.lucene.search.Query, org.apache.lucene.search.ScoreDoc, org.apache.lucene.search.TopDocs, org.apache.lucene.search.highlight.Highlighter, org.apache.lucene.search.highlight.InvalidTokenOffsetsException, org.apache.lucene.search.highlight.QueryScorer, org.apache.lucene.search.highlight.SimpleFragmenter, org.apache.lucene.store.FSDirectory" %>

<%
/*
    Author: Andrew C. Oliver, SuperLink Software, Inc. (acoliver2@users.sourceforge.net)

    This jsp page is deliberatly written in the horrible java directly embedded
    in the page style for an easy and concise demonstration of Lucene.
    Due note...if you write pages that look like this...sooner or later
    you'll have a maintenance nightmare.  If you use jsps...use taglibs
    and beans!  That being said, this should be acceptable for a small
    page demonstrating how one uses Lucene in a web app. 

    This is also deliberately overcommented. ;-)
*/
%>
<%!
public String escapeHTML(String s) {
  s = s.replaceAll("&", "&amp;");
  s = s.replaceAll("<", "&lt;");
  s = s.replaceAll(">", "&gt;");
  s = s.replaceAll("\"", "&quot;");
  s = s.replaceAll("'", "&apos;");
  return s;
}

public String paging(String queryString, String rankingType,int maxpage, int page) {
    return "results.jsp?query=" +
            URLEncoder.encode(queryString) +
            "&amp;maxresults=" + maxpage + 
            "&amp;startat=" + (maxpage*(page-1)) +
            "&amp;rankingType=" + rankingType;
}
%>
<%@include file="header.jsp"%>
<%
    boolean error = false;                  //used to control flow for error messages
    String indexName = indexLocation;       //local copy of the configuration variable
    IndexSearcher searcher = null;          //the searcher used to open/search the index
    Query query = null;                     //the Query created by the QueryParser
    TopDocs hits = null;                    //the search results
    ScoreDoc[] hitsScore = null;
    int startindex = 0;                     //the first index displayed on this page
    int maxpage    = 50;                    //the maximum items displayed on this page
    int maxCharContent = 400;
    String queryString = null;              //the query entered in the previous page
    String startVal    = null;              //string version of startindex
    String maxresults  = null;              //string version of maxpage
    String rankingType = null;
    int thispage = 0;                       //used for the for/next either maxpage or
                                            //hits.totalHits - startindex - whichever is
                                            //less

    try {
        IndexReader reader = DirectoryReader.open(FSDirectory.open(Paths.get(indexName)));
        searcher = new IndexSearcher(reader);       //create an indexSearcher for our page
                                                    //NOTE: this operation is slow for large
                                                    //indices (much slower than the search itself)
                                                    //so you might want to keep an IndexSearcher 
                                                    //open
                                                    
    } catch (Exception e) {                         //any error that happens is probably due
                                                    //to a permission problem or non-existant
                                                    //or otherwise corrupt index
%>
        <p>ERROR opening the Index - contact sysadmin!</p>
        <p>Error message: <%=escapeHTML(e.getMessage())%></p>   
<%      error = true;                                   //don't do anything up to the footer
    }
%>
<%
    if (error == false) {                                           //did we open the index?
        queryString = request.getParameter("query");                //get the search criteria
        startVal    = request.getParameter("startat");              //get the start index
        maxresults  = request.getParameter("maxresults");           //get max results per page
        rankingType = request.getParameter("rankingType");
        try {
            maxpage    = Integer.parseInt(maxresults);              //parse the max results first
            startindex = Integer.parseInt(startVal);                //then the start index
        } catch (Exception e) { } //we don't care if something happens we'll just start at 0 or end at 50

        if (queryString == null)
            throw new ServletException("no query sepcified");   //if you don't have a query then
                                                                //you probably played on the
                                                                //query string so you get the
                                                                //treatment
        Analyzer analyzer = new ThaiAnalyzer();
        try {
                QueryParser qp = new QueryParser("contents", analyzer);
                query = qp.parse(queryString.trim()); //parse the query and construct the Query object
        } catch (ParseException e) {                  //if it's just "operator error" send them a nice error HTML
%>
        <p>Error while parsing query: <%=escapeHTML(e.getMessage())%></p>
<%
            error = true;                               //don't bother with the rest of the page
        }
    }
%>
<%
    if (error == false && searcher != null) {                     // if we've had no errors searcher != null was to handle a weird compilation bug
        thispage = maxpage;                                       // default last element to maxpage

        final IndexSearcher tempSearcher = searcher;
        final String rt = rankingType;
        hits = searcher.search(query, maxpage + startindex);      // run the query
        hitsScore = hits.scoreDocs;

        if(rt.equals("pr") || rt.equals("cos-pr")) {
            Arrays.sort(hitsScore, (ScoreDoc o1, ScoreDoc o2) -> {
                double pr1 = 0, pr2 = 0;
                double score1 = 0, score2 = 0, omega = 0.5;
                try {
                    pr1 = Double.parseDouble(tempSearcher.doc(o1.doc).get("PageRank"));
                    pr2 = Double.parseDouble(tempSearcher.doc(o2.doc).get("PageRank"));
                } catch (IOException e) {
                    e.printStackTrace();
                }

                if (rt.equals("pr")) {
                    score1 = pr1;
                    score2 = pr2;
                } else {
                    score1 = omega*o1.score + (1-omega)*pr1;
                    score2 = omega*o2.score + (1-omega)*pr2;
                }

                if (score1 < score2) return (1);
                else if (score1 == score2) return (0);
                else return (-1);
            });
        } 

        if (hits.totalHits == 0) {                                // if we got no results tell the user
%>
        <p> I'm sorry I couldn't find what you were looking for. </p>
<%
            error = true;                                         // don't bother with the rest of the page
        }
    }

        if (error == false && searcher != null) {
%>
    <div class="container">
        <h3>Result</h3>
        <p>About <%=hits.totalHits%> results</p>
        <br />
        <table>
<%
            if ((startindex + maxpage) > hits.totalHits) {
                    thispage = hits.totalHits - startindex;      // set the max index to maxpage or last
            }                                                    // actual search result whichever is less

            for (int i = startindex; i < (thispage + startindex); i++) {  // for each element
                Document doc = searcher.doc(hitsScore[i].doc);          //get the next document
                String doctitle = doc.get("title");                          //get its title
                String docContents = doc.get("contents");
                String url = doc.get("path");                                //get its path field
                if (url != null && url.startsWith("../webapps/")) {          // strip off ../webapps prefix if present
                    url = url.substring(10);
                }
                if ((doctitle == null) || doctitle.equals("")) {//use the path if it has no title
                    doctitle = doc.get("url");
                }
                if(docContents.length() > maxCharContent) {
                    docContents = docContents.substring(0, Math.min(docContents.length(), maxCharContent)) + "...";
                }
%>
            <tr>
                <td>
                    <a
                        href="<%=doc.get("url")%>"
                        style="color: blue; font-size: 1.2em;">
                        <%=doctitle%>
                    </a>
                </td>
            </tr>
            <tr>
                <td>
                    <span style="color:green;text-decoration: none; font-size: 0.9em"><%=doc.get("url")%></span>
                </td>
            </tr>
            <tr>
                <td style="font-size: 0.9em"><%=docContents%></td>
            </tr>
            <tr>
                <td><br /><br /></td>
            </tr>
<%
            }
%>
<%          if ((startindex + maxpage) < hits.totalHits) {   //if there are more results...display the more link

                String moreurl="results.jsp?query=" +
                        URLEncoder.encode(queryString) +  //construct the "more" link
                        "&amp;maxresults=" + maxpage + 
                        "&amp;startat=" + (startindex + maxpage) +
                        "&amp;rankingType=" + rankingType;
%>
                <tr style="display: flex; justify-content: center;">
                    <td>
<%
                int totalPages = hits.totalHits/maxpage;
                int showedPage = 10;
                if(totalPages < showedPage) {
                    showedPage = totalPages;
                }

                for(int i = 1; i <= showedPage; i++) {
%>
                        <a href="<%=paging(queryString, rankingType, maxpage, i)%>" style="margin: 0 15px"><%=i%></a>
<%
                }
%>
                        <a href="<%=moreurl%>">Next >></a>
                    </td>
                </tr>
<%
            }
%>
        </table>
    </div>
    <br />
    <br />
    <br />
    <br />
    <br />
    <br />

<%  }                                    //then include our footer.
         //if (searcher != null)
         //       searcher.close();
%>
<%@include file="footer.jsp"%>
