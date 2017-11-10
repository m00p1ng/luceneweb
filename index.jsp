<%@include file="header.jsp"%>
<%@page pageEncoding="UTF-8"%>
<% /* Author: Andrew C. Oliver (acoliver2@users.sourceforge.net) */ %>
<div class="content"> 
    <div class="card" style="padding: 5em">
        <div>
            <h1 class="center-content" style="margin-bottom: 40px; color: #444444;">KU Search</h1>
        <div>
        <form name="search" action="results.jsp" method="get">
            <div class="form-group">
                <input
                    type="text"
                    name="query"
                    size="44"
                    style="text-align: center"
                    class="form-control"
                    autofocus
                />
            </div>
            <div class="form-group center-content">
                <span style="display: flex; align-items: center;">Results&nbsp;</span>
                <input
                    type="text"
                    name="maxresults"
                    class="form-control"
                    style="width: 60px; text-align: center;"
                    value="10"
                />
                &nbsp;
                <select name="rankingType" class="form-control" style="width: 210px">
                    <option value="cos">Cosine Sim</option>
                    <option value="pr">Pagerank</option>
                    <option value="cos-pr">Cosine Sim &amp; Pagerank</option>
                </select>
            </div>
            <div class="form-group center-content">
                <button class="btn btn-primary" type="submit" style="padding: 0.4rem 1.5rem">Search</button>
            </div>
        </form>
    </div>
</div>
<%@include file="footer.jsp"%>

<style>
.content {
    height: 80vh;
    display: flex;
    justify-content: center;
    align-items: center;
}

.center-content {
    display: flex;
    justify-content: center;
}
</style>