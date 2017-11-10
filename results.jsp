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
            "&amp;page=" + page +
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
    int maxCharContent = 200;
    String queryString = null;              //the query entered in the previous page
    String startVal    = null;              //string version of startindex
    String maxresults  = null;              //string version of maxpage
    String rankingType = null;
    String rankBy = null;
    int showedPage = 10;
    int totalPages = 0;
    Analyzer analyzer = new ThaiAnalyzer();
    int crPage = 0;
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

    if (error == false) {                                           //did we open the index?
        queryString = request.getParameter("query");                //get the search criteria
        startVal    = request.getParameter("page");              //get the start index
        maxresults  = request.getParameter("maxresults");           //get max results per page
        rankingType = request.getParameter("rankingType");
        try {
            maxpage    = Integer.parseInt(maxresults);              //parse the max results first
            startindex = maxpage*(Integer.parseInt(startVal)-1);    //then the start index
        } catch (Exception e) { } //we don't care if something happens we'll just start at 0 or end at 50

        if(rankingType.equals("cos")) {
            rankBy = "Cosine Similarity";
        } else if(rankingType.equals("pr")) {
            rankBy = "PageRank";
        } else if(rankingType.equals("cos-pr")) {
            rankBy = "Cosine Similarity & PageRank";
        }

        crPage = (startindex/maxpage)+1;

        if (queryString == null)
            throw new ServletException("no query sepcified");   //if you don't have a query then
                                                                //you probably played on the
                                                                //query string so you get the
                                                                //treatment
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

    totalPages = hits.totalHits/maxpage + 1;
    if (error == false && searcher != null) {
%>
    <div class="container" style="font-family: arial, sans-serif">
        <div class="row">
            <div class="col-lg-7">
                <h1 style="margin: 1em 0 0 0;"><a href="./" style="color: #444444;">KU Search</a></h1>
                <p style="color: #808080; margin-bottom: 1.8em">Page <%=crPage%>/<%=totalPages%> of about <%=hits.totalHits%> results (<%=rankBy%>)</p>
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

            QueryScorer queryScorer = new QueryScorer(query);
            Highlighter highlighter = new Highlighter(queryScorer);
            TokenStream tokenStream = analyzer.tokenStream("contents", docContents);
            highlighter.setTextFragmenter(new SimpleFragmenter(100));
            try {
                String fragment = highlighter.getBestFragments(tokenStream, docContents, 2, ".");
                docContents = fragment.replaceAll("( +)|(\\[\\])", " ").replaceAll("\\s", " ");
            } catch (InvalidTokenOffsetsException e) {
                // TODO Auto-generated catch block
                e.printStackTrace();
            }
%>
                <div style="margin-bottom: -1.5em">
                    <div class="text-truncate">
                        <a href="<%=doc.get("url")%>" style="color: #1a0dab; font-size: 18px;"> <%=doctitle%></a>
                    </div>
                    <div class="text-truncate">
                        <span style="color:#006621; font-size: 14px"><%=doc.get("url")%></span>
                    </div>
                    <span class="doc-content"><%=escapeHTML(docContents).replaceAll("&lt;B&gt;", "<B>").replaceAll("&lt;/B&gt;", "</B>")%></span>
                    <br /><br />
                </div>
<%
        }
%>
                <div style="display: flex; justify-content: center; margin-bottom: 10em">
<%
        if(totalPages < showedPage) {
            showedPage = totalPages;
        }

        if(crPage > 1) {
%>
                    <a class="pagee-link" href="<%=paging(queryString, rankingType, maxpage, crPage-1)%>">< Prev</a>
<%
        }

        int strPg = 0;
        int endPg = 0;
        int shDiv = showedPage/2;
        if(totalPages <= showedPage) {
            strPg = 1;
            endPg = totalPages;
        } else if(crPage < shDiv) {
            strPg = 1;
            endPg = showedPage;

        } else if(crPage >= shDiv && crPage < totalPages - shDiv) {
            strPg = crPage - shDiv + 1;
            endPg = crPage + shDiv;
        } else {
            strPg = totalPages - showedPage + 1;
            endPg = totalPages;
        }

        for(int i = strPg; i <= endPg; i++) {
            if (crPage == i) {
%>
                    <a class="pagee-link acctive"><%=i%></a>
<%
            } else {
%>
                    <a class="pagee-link" href="<%=paging(queryString, rankingType, maxpage, i)%>"><%=i%></a>
<%
            }
        }

        if (crPage < totalPages) {   //if there are more results...display the more link
%>
                    <a class="pagee-link" href="<%=paging(queryString, rankingType, maxpage, crPage+1)%>">Next ></a>
<%
        }
%>
                </div>
            </div>
        </div>
    </div>
    <style>
    .doc-content > b {
        color: #dd4b39;
        font-weight: normal;
    }

    .doc-content {
        font-size: 14px;
        color: #545454;

        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    .pagee-link {
        color: #4285f4;
        margin: 0 0.6em;
        font-size: 14px;
    }

    .acctive {
        color: rgba(0, 0, 0, 0.87);
    }
    </style>

<%
    }                                    //then include our footer.
%>
<%@include file="footer.jsp"%>
